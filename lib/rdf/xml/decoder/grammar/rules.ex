defmodule RDF.XML.Decoder.Grammar.Rules do
  alias RDF.XML.Decoder.Grammar.{ElementRule, AlternationRule, SequenceRule}
  alias RDF.XML.Decoder.ElementNode
  alias RDF.{Graph, Description, Literal, LangString}

  alias __MODULE__

  defmodule Doc do
    use AlternationRule,
      production: [Rules.RDF, Rules.NodeElement]

    def select_production(_, %{name: "rdf:RDF"}), do: Rules.RDF
    def select_production(_, _), do: Rules.NodeElement

    def at_end(cxt, graph, bnodes) do
      {:ok, cxt, graph, bnodes}
    end
  end

  defmodule RDF do
    use ElementRule,
      production: Rules.NodeElementList,
      # we don't store the children, since this would mean building up a tree of the whole document,
      # which isn't needed and would just consume potentially a lot of memory
      no_children: true

    def uri_constraint(uri), do: uri == "rdf:RDF"

    def at_end(cxt, graph, bnodes) do
      {:ok, cxt, Graph.add_prefixes(graph, cxt.element.ns_declarations), bnodes}
    end
  end

  defmodule NodeElementList do
    use SequenceRule,
      production: Rules.NodeElement

    def at_end(%{children: node_element_list}, graph, bnodes) do
      {:ok, node_element_list, graph, bnodes}
    end
  end

  defmodule NodeElement do
    use ElementRule,
      production: Rules.PropertyEltList,
      struct: [:subject]

    def at_start(cxt, _graph, bnodes) do
      {subject, new_bnodes} =
        cond do
          id = cxt.element.rdf_attributes[:id] ->
            {id, bnodes}

          node_id = cxt.element.rdf_attributes[:node_id] ->
            bnodeid(node_id, bnodes)

          about = cxt.element.rdf_attributes[:about] ->
            {resolve(about, cxt.element), bnodes}

          true ->
            generated_blank_node_id(bnodes)
        end

      {:ok, %{cxt | subject: subject}, new_bnodes}
    end

    def at_end(cxt, graph, bnodes) do
      description = Description.new(cxt.subject)

      description =
        unless cxt.element.name == "rdf:Description" do
          Description.add(description, {Elixir.RDF.type(), cxt.element.uri})
        else
          description
        end

      description = description_from_property_attrs(cxt, description)

      {:ok, cxt, Graph.add(graph, description), bnodes}
    end
  end

  defmodule PropertyEltList do
    use SequenceRule, production: Rules.PropertyElt

    def at_end(%{children: property_element_list}, graph, bnodes) do
      {:ok, property_element_list, graph, bnodes}
    end
  end

  defmodule PropertyElt do
    use AlternationRule,
      production: [
        # TODO: Rules.ParseTypeLiteralPropertyElt,
        # TODO: Rules.ParseTypeOtherPropertyElt,
        Rules.ParseTypeResourcePropertyElt,
        Rules.ParseTypeCollectionPropertyElt,
        Rules.LiteralPropertyElt,
        Rules.ResourcePropertyElt,
        Rules.EmptyPropertyElt
      ]

    def at_start(element, cxt, _graph, bnodes) do
      if element.name == "rdf:li" do
        {li_counter, new_cxt} =
          get_and_update_in(cxt.parent_cxt.parent_cxt.element.li_counter, &{&1, &1 + 1})

        {
          :ok,
          ElementNode.update_name(element, "rdf:_#{li_counter}"),
          new_cxt,
          bnodes
        }
      else
        {:ok, element, cxt, bnodes}
      end
    end

    def at_end(%{children: [property_element]}, graph, bnodes) do
      {:ok, property_element, graph, bnodes}
    end
  end

  defmodule LiteralPropertyElt do
    use ElementRule, struct: [:t]

    @allowed_attributes ~w[id datatype]a

    def conform?(element) do
      Rules.property_element_uri?(element.name) &&
        Enum.empty?(element.property_attributes) &&
        element.rdf_attributes
        |> Map.keys()
        |> Enum.all?(&(&1 in @allowed_attributes))
    end

    def characters(characters, cxt) do
      {:ok, %{cxt | t: characters}}
    end

    def at_end(cxt, graph, bnodes) do
      t = cxt.t || ""

      o =
        cond do
          cxt.element.rdf_attributes[:datatype] ->
            Literal.new(t, datatype: cxt.element.rdf_attributes.datatype)

          cxt.element.language ->
            LangString.new(t, language: cxt.element.language)

          true ->
            t
        end

      statement = {parent(cxt).subject, cxt.element.uri, o}

      statements =
        if rdf_id = cxt.element.rdf_attributes[:id] do
          [statement, reify(statement, rdf_id)]
        else
          statement
        end

      {:ok, cxt, Graph.add(graph, statements), bnodes}
    end
  end

  defmodule ResourcePropertyElt do
    use ElementRule, production: Rules.NodeElement

    def conform?(element) do
      Rules.property_element_uri?(element.name) &&
        Enum.empty?(element.property_attributes) &&
        Map.keys(element.rdf_attributes) in [[], [:id]]
    end

    def at_end(%{children: nil}, _, _) do
      {:error, "this case should happen only during elimination of alternative productions"}
    end

    def at_end(%{children: [n]} = cxt, graph, bnodes) do
      statement = {parent(cxt).subject, cxt.element.uri, n.subject}

      statements =
        if rdf_id = cxt.element.rdf_attributes[:id] do
          [statement, reify(statement, rdf_id)]
        else
          statement
        end

      {:ok, cxt, Graph.add(graph, statements), bnodes}
    end
  end

  defmodule EmptyPropertyElt do
    use ElementRule

    # TODO: Where is the allowed datatype attribute used?
    @one_of ~w[resource node_id datatype]a
    @allowed_attributes [:id | @one_of]

    def conform?(element) do
      Rules.property_element_uri?(element.name) &&
        element.rdf_attributes
        |> Map.keys()
        |> Enum.all?(&(&1 in @allowed_attributes)) &&
        element.rdf_attributes
        |> Map.take(@one_of)
        |> Enum.count() <= 1
    end

    def at_end(cxt, graph, bnodes) do
      {r, new_bnodes} =
        cond do
          resource = cxt.element.rdf_attributes[:resource] ->
            {resolve(resource, cxt.element), bnodes}

          node_id = cxt.element.rdf_attributes[:node_id] ->
            bnodeid(node_id, bnodes)

          true ->
            generated_blank_node_id(bnodes)
        end

      statements = [
        statement = {parent(cxt).subject, cxt.element.uri, r},
        description_from_property_attrs(cxt, r)
      ]

      statements =
        if rdf_id = cxt.element.rdf_attributes[:id] do
          [reify(statement, rdf_id) | statements]
        else
          statements
        end

      {:ok, cxt, Graph.add(graph, statements), new_bnodes}
    end
  end

  defmodule ParseTypeResourcePropertyElt do
    use ElementRule,
      production: Rules.PropertyEltList,
      struct: [:subject]

    def conform?(element) do
      element.rdf_attributes[:parseResource] &&
        Rules.property_element_uri?(element.name) &&
        Enum.empty?(element.property_attributes) &&
        element.rdf_attributes |> Map.drop(~w[id parseResource]a) |> Map.keys() |> Enum.empty?()
    end

    def at_start(cxt, _graph, bnodes) do
      {n, new_bnodes} = generated_blank_node_id(bnodes)
      {:ok, %{cxt | subject: n}, new_bnodes}
    end

    def at_end(cxt, graph, bnodes) do
      statement = {parent(cxt).subject, cxt.element.uri, cxt.subject}

      statements =
        if rdf_id = cxt.element.rdf_attributes[:id] do
          [statement, reify(statement, rdf_id)]
        else
          statement
        end

      {:ok, cxt, Graph.add(graph, statements), bnodes}
    end
  end

  defmodule ParseTypeCollectionPropertyElt do
    use ElementRule,
      production: Rules.NodeElementList

    @rdf_first Elixir.RDF.first()
    @rdf_rest Elixir.RDF.rest()
    @rdf_nil Elixir.RDF.nil()

    def conform?(element) do
      element.rdf_attributes[:parseCollection] &&
        Rules.property_element_uri?(element.name) &&
        Enum.empty?(element.property_attributes) &&
        element.rdf_attributes |> Map.drop(~w[id parseCollection]a) |> Map.keys() |> Enum.empty?()
    end

    def at_end(cxt, graph, bnodes) do
      {n, bnodes} = generated_blank_node_id(bnodes)

      {graph, bnodes} =
        if Enum.empty?(cxt.children) do
          statement = {parent(cxt).subject, cxt.element.uri, RDF.nil()}

          statements =
            if rdf_id = cxt.element.rdf_attributes[:id] do
              [statement, reify(statement, rdf_id)]
            else
              statement
            end

          {
            Graph.add(graph, statements),
            bnodes
          }
        else
          statement = {parent(cxt).subject, cxt.element.uri, n}

          statements =
            if rdf_id = cxt.element.rdf_attributes[:id] do
              [statement, reify(statement, rdf_id)]
            else
              statement
            end

          add_as_rdf_collection(
            Enum.reverse(cxt.children),
            n,
            Graph.add(graph, statements),
            bnodes
          )
        end

      {:ok, cxt, graph, bnodes}
    end

    def add_as_rdf_collection([first], n, graph, bnodes) do
      {
        Graph.add(graph, [
          {n, @rdf_first, first.subject},
          {n, @rdf_rest, @rdf_nil}
        ]),
        bnodes
      }
    end

    def add_as_rdf_collection([first | rest], n, graph, bnodes) do
      {o, bnodes} = generated_blank_node_id(bnodes)

      add_as_rdf_collection(
        rest,
        o,
        Graph.add(graph, [
          {n, @rdf_first, first.subject},
          {n, @rdf_rest, o}
        ]),
        bnodes
      )
    end
  end

  @core_syntax_terms ~w[rdf:RDF rdf:ID rdf:about rdf:parseType rdf:resource rdf:nodeID rdf:datatype]
  @syntax_terms ~w[rdf:Description rdf:li] ++ @core_syntax_terms
  @old_terms ~w[rdf:aboutEach rdf:aboutEachPrefix rdf:bagID]

  def core_syntax_term?(term), do: term in @core_syntax_terms
  def syntax_term?(term), do: term in @syntax_terms
  def old_term?(term), do: term in @old_terms

  def node_element_uri?("rdf:li"), do: false
  def node_element_uri?(uri), do: uri not in @core_syntax_terms and uri not in @old_terms

  def property_element_uri?("rdf:Description"), do: false
  def property_element_uri?(uri), do: uri not in @core_syntax_terms and uri not in @old_terms

  def property_attribute_uri?("rdf:Description"), do: false
  def property_attribute_uri?("rdf:li"), do: false
  def property_attribute_uri?(uri), do: uri not in @core_syntax_terms and uri not in @old_terms
end

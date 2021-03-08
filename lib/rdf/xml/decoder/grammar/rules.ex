defmodule RDF.XML.Decoder.Grammar.Rules do
  @moduledoc false

  alias RDF.XML.Decoder
  alias RDF.XML.Decoder.ElementNode
  alias RDF.XML.Decoder.Grammar.{ElementRule, AlternationRule, SequenceRule, LiteralRule}
  alias RDF.{Graph, Description, Literal, LangString}

  alias __MODULE__

  ["rdf:Description" | Decoder.core_syntax_terms() ++ Decoder.old_terms()]
  |> Enum.each(fn term ->
    def property_element_uri?(unquote(term)), do: false
  end)

  def property_element_uri?(_), do: true

  defmodule Doc do
    use AlternationRule,
      production: [Rules.OuterRDF, Rules.NodeElement]

    def select_production(_, %{name: "rdf:RDF"}), do: Rules.OuterRDF
    def select_production(_, _), do: Rules.NodeElement
  end

  defmodule OuterRDF do
    use ElementRule,
      production: Rules.NodeElementList,
      # we don't store the children, since this would mean building up a tree of the whole document,
      # which isn't needed and would just consume potentially a lot of memory
      no_children: true

    def conform?(%{name: "rdf:RDF"}), do: true
    def conform?(_), do: false

    def at_end(cxt, graph, bnodes) do
      graph =
        if cxt.element.base_uri do
          Graph.set_base_iri(graph, cxt.element.base_uri)
        else
          graph
        end
        |> Graph.add_prefixes(cxt.element.ns_declarations)

      {:ok, graph, bnodes}
    end
  end

  defmodule NodeElementList do
    use SequenceRule,
      production: Rules.NodeElement
  end

  defmodule NodeElement do
    use ElementRule,
      production: Rules.PropertyEltList,
      struct: [:subject]

    ["rdf:li" | Decoder.core_syntax_terms() ++ Decoder.old_terms()]
    |> Enum.each(fn term ->
      def conform?(%{name: unquote(term)}), do: false
    end)

    def conform?(_), do: true

    def at_start(cxt, _graph, bnodes) do
      cond do
        id = cxt.element.rdf_attributes[:id] ->
          {id, bnodes}

        node_id = cxt.element.rdf_attributes[:node_id] ->
          bnodeid(node_id, bnodes)

        about = cxt.element.rdf_attributes[:about] ->
          with {:ok, subject} <- resolve(about, cxt.element) do
            {subject, bnodes}
          end

        true ->
          generated_blank_node_id(bnodes)
      end
      |> case do
        {:error, _} = error ->
          error

        {subject, new_bnodes} ->
          {:ok, %{cxt | subject: subject}, new_bnodes}
      end
    end

    def at_end(cxt, graph, bnodes) do
      description = Description.new(cxt.subject)

      description =
        unless cxt.element.name == "rdf:Description" do
          Description.add(description, {RDF.type(), cxt.element.uri})
        else
          description
        end

      with {:ok, description} <- description_from_property_attrs(cxt, description) do
        {:ok, Graph.add(graph, description), bnodes}
      end
    end
  end

  defmodule PropertyEltList do
    use SequenceRule, production: Rules.PropertyElt
  end

  defmodule PropertyElt do
    use AlternationRule,
      production: [
        Rules.ParseTypeResourcePropertyElt,
        Rules.ParseTypeCollectionPropertyElt,
        Rules.ParseTypeLiteralPropertyElt,
        Rules.ParseTypeOtherPropertyElt,
        Rules.LiteralPropertyElt,
        Rules.ResourcePropertyElt,
        Rules.EmptyPropertyElt
      ]

    def select_production(_, %{rdf_attributes: %{parseLiteral: true}}),
      do: Rules.ParseTypeLiteralPropertyElt

    def select_production(_, %{rdf_attributes: %{parseOther: other}}) when not is_nil(other),
      do: Rules.ParseTypeOtherPropertyElt

    def select_production(_, %{rdf_attributes: %{parseResource: true}}),
      do: Rules.ParseTypeResourcePropertyElt

    def select_production(_, %{rdf_attributes: %{parseCollection: true}}),
      do: Rules.ParseTypeCollectionPropertyElt

    def select_production(_, %{rdf_attributes: %{resource: resource}})
        when not is_nil(resource),
        do: Rules.EmptyPropertyElt

    def select_production(_, %{rdf_attributes: %{node_id: node_id}})
        when not is_nil(node_id),
        do: Rules.EmptyPropertyElt

    def select_production(_, %{property_attributes: attr})
        when map_size(attr) > 0,
        do: Rules.EmptyPropertyElt

    def select_production(_, %{rdf_attributes: %{datatype: datatype}})
        when not is_nil(datatype),
        do: [Rules.LiteralPropertyElt, Rules.EmptyPropertyElt]

    def select_production(_, _),
      do: [Rules.LiteralPropertyElt, Rules.ResourcePropertyElt, Rules.EmptyPropertyElt]

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
  end

  defmodule LiteralPropertyElt do
    use ElementRule, struct: [:t]

    def conform?(element) do
      Rules.property_element_uri?(element.name)
    end

    def characters(characters, cxt) do
      {:ok, %{cxt | t: characters}}
    end

    def at_end(%{t: nil}, _, _) do
      {:error, "this case should happen only during elimination of alternative productions"}
    end

    def at_end(cxt, graph, bnodes) do
      t = cxt.t

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

      {:ok, Graph.add(graph, statements), bnodes}
    end
  end

  defmodule ResourcePropertyElt do
    use ElementRule, production: Rules.NodeElement

    def conform?(element) do
      Rules.property_element_uri?(element.name)
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

      {:ok, Graph.add(graph, statements), bnodes}
    end
  end

  defmodule EmptyPropertyElt do
    use ElementRule

    # TODO: Where is the allowed datatype attribute used?
    @one_of ~w[resource node_id datatype]a

    def conform?(element) do
      Rules.property_element_uri?(element.name) &&
        element.rdf_attributes
        |> Map.take(@one_of)
        |> Enum.count() <= 1
    end

    def at_end(cxt, graph, bnodes) do
      if Enum.empty?(cxt.element.rdf_attributes) or
           (Enum.count(cxt.element.rdf_attributes) == 1 && cxt.element.rdf_attributes[:id]) do
        o =
          if cxt.element.language do
            LangString.new("", language: cxt.element.language)
          else
            ""
          end

        statement = {parent(cxt).subject, cxt.element.uri, o}

        statements =
          if rdf_id = cxt.element.rdf_attributes[:id] do
            [statement, reify(statement, rdf_id)]
          else
            statement
          end

        {:ok, Graph.add(graph, statements), bnodes}
      else
        cond do
          resource = cxt.element.rdf_attributes[:resource] ->
            with {:ok, uri} <- resolve(resource, cxt.element) do
              {uri, bnodes}
            end

          node_id = cxt.element.rdf_attributes[:node_id] ->
            bnodeid(node_id, bnodes)

          true ->
            generated_blank_node_id(bnodes)
        end
        |> case do
          {:error, _} = error ->
            error

          {r, new_bnodes} ->
            with {:ok, description} <- description_from_property_attrs(cxt, r) do
              statements = [
                statement = {parent(cxt).subject, cxt.element.uri, r},
                description
              ]

              statements =
                if rdf_id = cxt.element.rdf_attributes[:id] do
                  [reify(statement, rdf_id) | statements]
                else
                  statements
                end

              {:ok, Graph.add(graph, statements), new_bnodes}
            end
        end
      end
    end
  end

  defmodule ParseTypeResourcePropertyElt do
    use ElementRule,
      production: Rules.PropertyEltList,
      struct: [:subject]

    def conform?(element) do
      Rules.property_element_uri?(element.name) &&
        Enum.empty?(element.property_attributes) &&
        element.rdf_attributes
        |> Map.drop(~w[id parseResource]a)
        |> Map.keys()
        |> Enum.empty?()
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

      {:ok, Graph.add(graph, statements), bnodes}
    end
  end

  defmodule ParseTypeCollectionPropertyElt do
    use ElementRule,
      production: Rules.NodeElementList

    @rdf_first RDF.first()
    @rdf_rest RDF.rest()
    @rdf_nil RDF.nil()

    def conform?(element) do
      Rules.property_element_uri?(element.name) &&
        Enum.empty?(element.property_attributes) &&
        element.rdf_attributes
        |> Map.drop(~w[id parseCollection]a)
        |> Map.keys()
        |> Enum.empty?()
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
            # We need to reverse children, since they are stored in reverse order. See RDF.XML.Decoder.Grammar.Rule.update_children/2
            Enum.reverse(cxt.children),
            n,
            Graph.add(graph, statements),
            bnodes
          )
        end

      {:ok, graph, bnodes}
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

  defmodule ParseTypeLiteralPropertyElt do
    use ElementRule, production: LiteralRule

    def conform?(element) do
      Rules.property_element_uri?(element.name) &&
        Enum.empty?(element.property_attributes) &&
        element.rdf_attributes
        |> Map.drop(~w[id parseLiteral]a)
        |> Map.keys()
        |> Enum.empty?()
    end

    defdelegate characters(characters, cxt), to: LiteralRule

    def at_end(cxt, graph, bnodes) do
      xml_literal =
        cxt.children
        |> List.wrap()
        |> Enum.reverse()
        |> Enum.map_join(fn
          {_, _, _} = element -> Saxy.encode!(element)
          {_, characters} -> characters
        end)
        |> Literal.new(datatype: RDF.XMLLiteral)

      statement = {parent(cxt).subject, cxt.element.uri, xml_literal}

      statements =
        if rdf_id = cxt.element.rdf_attributes[:id] do
          [statement, reify(statement, rdf_id)]
        else
          statement
        end

      {:ok, Graph.add(graph, statements), bnodes}
    end
  end

  defmodule ParseTypeOtherPropertyElt do
    # TODO: The spec specifies the production to be Rules.PropertyEltList ... Why is that if it should behave like ParseTypeLiteralPropertyElt?
    use ElementRule, production: LiteralRule

    def conform?(element) do
      Rules.property_element_uri?(element.name) &&
        Enum.empty?(element.property_attributes) &&
        element.rdf_attributes
        |> Map.drop(~w[id parseOther]a)
        |> Map.keys()
        |> Enum.empty?()
    end

    defdelegate characters(characters, cxt), to: LiteralRule

    def at_end(_cxt, graph, bnodes) do
      {:ok, graph, bnodes}
    end
  end
end

defmodule RDF.XML.Decoder.Grammar.Rules do
  alias RDF.XML.Decoder.Grammar.{ElementRule, AlternationRule, SequenceRule, Rule}
  alias RDF.{Graph, Description, Literal, LangString}

  alias __MODULE__

  defmodule Doc do
    use AlternationRule,
      production: [Rules.RDF, Rules.NodeElement]

    def select_production(_, %{name: "rdf:RDF"}), do: Rules.RDF
    def select_production(_, _), do: Rules.NodeElement

    def at_end(cxt, graph) do
      {:ok, cxt, graph}
    end
  end

  defmodule RDF do
    use ElementRule,
      production: Rules.NodeElementList,
      # we don't store the children, since this would mean building up a tree of the whole document,
      # which isn't needed and would just consume potentially a lot of memory
      no_children: true

    def uri_constraint(uri), do: uri == "rdf:RDF"

    def at_end(cxt, graph) do
      {:ok, cxt, Graph.add_prefixes(graph, cxt.element.ns_declarations)}
    end
  end

  defmodule NodeElementList do
    use SequenceRule,
      production: Rules.NodeElement

    def at_end(%{children: node_element_list}, graph) do
      {:ok, node_element_list, graph}
    end
  end

  defmodule NodeElement do
    use ElementRule,
      production: Rules.PropertyEltList,
      struct: [:subject]

    def at_start(cxt, graph) do
      subject =
        cond do
          id = cxt.element.rdf_attributes[:id] ->
            id

          node_id = cxt.element.rdf_attributes[:node_id] ->
            node_id

          about = cxt.element.rdf_attributes[:about] ->
            resolve(about, cxt.element)

          true ->
            raise "TODO: generated-blank-node-id()"
        end

      {:ok, %{cxt | subject: subject}}
    end

    def at_end(cxt, graph) do
      description = Description.new(cxt.subject)

      description =
        unless cxt.element.name == "rdf:Description" do
          Description.add(description, {Elixir.RDF.type(), cxt.element.uri})
        else
          description
        end

      description = description_from_property_attrs(cxt, description)

      {:ok, cxt, Graph.add(graph, description)}
    end
  end

  defmodule PropertyEltList do
    use SequenceRule, production: Rules.PropertyElt

    def at_end(%{children: property_element_list}, graph) do
      {:ok, property_element_list, graph}
    end
  end

  defmodule PropertyElt do
    use AlternationRule,
      production: [
        # TODO: Rules.ParseTypeLiteralPropertyElt,
        # TODO: Rules.ParseTypeResourcePropertyElt,
        # TODO: Rules.ParseTypeCollectionPropertyElt,
        # TODO: Rules.ParseTypeOtherPropertyElt,
        Rules.LiteralPropertyElt,
        Rules.ResourcePropertyElt,
        Rules.EmptyPropertyElt
      ]

    def at_end(%{children: [property_element]}, graph) do
      {:ok, property_element, graph}
    end
  end

  defmodule LiteralPropertyElt do
    use ElementRule, struct: [:t]

    @allowed_attributes ~w[id datatype]a

    def conform?(element) do
      Rules.property_element_uri?(element.name) &&
        Enum.empty?(element.property_attributes()) &&
        element.rdf_attributes
        |> Map.keys()
        |> Enum.all?(&(&1 in @allowed_attributes))
    end

    def characters(characters, cxt) do
      {:ok, %{cxt | t: characters}}
    end

    def at_end(cxt, graph) do
      o =
        cond do
          cxt.element.rdf_attributes[:datatype] ->
            Literal.new(cxt.t, datatype: cxt.element.rdf_attributes.datatype)

          cxt.element.language ->
            LangString.new(cxt.t, language: cxt.element.language)

          true ->
            cxt.t
        end

      # TODO: If the rdf:ID attribute a is given, the above statement is reified ...
      {:ok, cxt, Graph.add(graph, {parent(cxt).subject, cxt.element.uri, o})}
    end
  end

  defmodule ResourcePropertyElt do
    use ElementRule, production: Rules.NodeElement

    def conform?(element) do
      Rules.property_element_uri?(element.name) &&
        Enum.empty?(element.property_attributes()) &&
        Map.keys(element.rdf_attributes) in [[], [:id]]
    end

    def at_end(%{children: [n]} = cxt, graph) do
      # TODO: If the rdf:ID attribute a is given, the above statement is reified ...
      {:ok, cxt, Graph.add(graph, {parent(cxt).subject, cxt.element.uri, n.subject})}
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

    def at_end(cxt, graph) do
      # TODO: If there are no attributes or only the optional rdf:ID attribute i then ...
      r =
        cond do
          resource = cxt.element.rdf_attributes[:resource] ->
            resolve(resource, cxt.element)

          node_id = cxt.element.rdf_attributes[:node_id] ->
            #            BlankNode.new(node_id)
            node_id

          true ->
            raise "TODO: generated-blank-node-id()"
        end

      statements = description_from_property_attrs(cxt, r)

      # TODO: and then if rdf:ID attribute i is given

      {:ok, cxt,
       Graph.add(graph, [
         statements,
         {parent(cxt).subject, cxt.element.uri, r}
       ])}
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

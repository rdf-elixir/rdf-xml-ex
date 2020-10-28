defmodule RDF.XML.Encoder do
  use RDF.Serialization.Encoder

  alias RDF.{Graph, Dataset, IRI, BlankNode, Literal, LangString, XSD, PrefixMap}
  import RDF.Utils
  import Saxy.XML

  @impl RDF.Serialization.Encoder
  @spec encode(Graph.t(), keyword) :: {:ok, String.t()} | {:error, any}
  def encode(data, opts \\ []) do
    prefixes = Keyword.get(opts, :prefixes) |> prefix_map(data)

    with {:ok, base} <-
           opts
           |> Keyword.get(:base, Keyword.get(opts, :base_iri))
           |> base_iri(data),
         {:ok, root} <- document(data, base, prefixes, opts) do
      {:ok, Saxy.encode!(root, version: "1.0", encoding: :utf8)}
    end
  end

  defp base_iri(nil, %Graph{base_iri: base_iri}) when not is_nil(base_iri),
    do: {:ok, to_string(base_iri)}

  defp base_iri(nil, _), do: RDF.default_base_iri() |> validate_base_iri()
  defp base_iri(base_iri, _), do: base_iri |> IRI.coerce_base() |> validate_base_iri()

  defp validate_base_iri(nil), do: {:ok, nil}

  defp validate_base_iri(base_iri) do
    base_iri = to_string(base_iri)

    if String.ends_with?(base_iri, ~w[/ #]) do
      {:ok, base_iri}
    else
      {:error, "invalid base_iri: #{base_iri}"}
    end
  end

  defp prefix_map(nil, %Graph{prefixes: prefixes}) when not is_nil(prefixes), do: prefixes

  defp prefix_map(nil, %Dataset{} = dataset) do
    prefixes = Dataset.prefixes(dataset)

    if Enum.empty?(prefixes) do
      RDF.default_prefixes()
    else
      prefixes
    end
  end

  defp prefix_map(nil, _), do: RDF.default_prefixes()
  defp prefix_map(prefixes, _), do: PrefixMap.new(prefixes)

  defp ns_declarations(prefixes, nil) do
    Enum.map(prefixes, fn {prefix, namespace} ->
      {"xmlns:#{prefix}", to_string(namespace)}
    end)
  end

  defp ns_declarations(prefixes, base) do
    [{"xml:base", to_string(base)} | ns_declarations(prefixes, nil)]
  end

  defp document(%Graph{} = graph, base, prefixes, opts) do
    with {:ok, descriptions} <- descriptions(graph, base, prefixes, opts) do
      {:ok,
       element(
         "rdf:RDF",
         ns_declarations(prefixes, base),
         descriptions
       )}
    end
  end

  defp descriptions(%Graph{} = graph, base, prefixes, opts) do
    graph
    |> Graph.descriptions()
    |> map_while_ok(&description(&1, graph, base, prefixes, opts))
  end

  defp description(description, graph, base, prefixes, opts) do
    {type_node, description} = type_node(description, graph, base, prefixes, opts)
    {property_attributes, description} = property_attributes(description, base, prefixes, opts)

    with {:ok, predications} <- predications(description, base, prefixes, opts) do
      {:ok,
       element(
         type_node || "rdf:Description",
         property_attributes
         |> add_description_id(description.subject, base, opts),
         predications
       )}
    end
  end

  defp type_node(description, graph, base, prefixes, opts) do
    # TODO: typed node
    {nil, description}
  end

  defp property_attributes(description, base, prefixes, opts) do
    # TODO: Property attributes
    {[], description}
  end

  defp add_description_id(attributes, %BlankNode{value: bnode}, _base, _opts) do
    [{"rdf:nodeID", bnode} | attributes]
  end

  defp add_description_id(attributes, %IRI{value: uri}, base, _opts) do
    [{"rdf:about", attr_val_uri(uri, base)} | attributes]
  end

  def predications(description, base, prefixes, opts) do
    flat_map_while_ok(description.predications, fn {predicate, objects} ->
      predications_for_property(predicate, objects, base, prefixes, opts)
    end)
  end

  def predications_for_property(property, objects, base, prefixes, opts) do
    if property_name = qname(property, prefixes) do
      {:ok,
       objects
       |> Map.keys()
       |> Enum.map(&statement(property_name, &1, base, prefixes, opts))}
    else
      {:error,
       %RDF.XML.EncodeError{message: "no namespace declaration for property #{property} found"}}
    end
  end

  defp statement(property_name, %IRI{value: uri}, base, _, _opts) do
    element(property_name, [{"rdf:resource", attr_val_uri(uri, base)}], [])
  end

  defp statement(property_name, %BlankNode{value: value}, _base, _, _opts) do
    element(property_name, [{"rdf:nodeID", value}], [])
  end

  defp statement(property_name, %Literal{} = literal, base, _, _opts) do
    element(property_name, literal_attributes(literal, base), Literal.lexical(literal))
  end

  defp literal_attributes(%Literal{literal: %LangString{language: language}}, _),
    do: [{"xml:lang", language}]

  defp literal_attributes(%Literal{literal: %XSD.String{}}, _), do: []

  defp literal_attributes(%Literal{literal: %datatype{}}, base),
    do: [{"rdf:datatype", datatype.id() |> attr_val_uri(base)}]

  defp literal_attributes(_, _), do: []

  defp attr_val_uri(iri, nil), do: iri

  defp attr_val_uri(iri, base) do
    String.replace_prefix(iri, base, "")
  end

  defp qname(iri, prefixes) do
    PrefixMap.prefixed_name(prefixes, iri)
  end
end

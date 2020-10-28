defmodule RDF.XML.Encoder do
  use RDF.Serialization.Encoder

  alias RDF.{Description, Graph, Dataset, IRI, BlankNode, Literal, LangString, XSD, PrefixMap}
  import RDF.Utils
  import Saxy.XML

  @impl RDF.Serialization.Encoder
  @spec encode(Graph.t(), keyword) :: {:ok, String.t()} | {:error, any}
  def encode(data, opts \\ []) do
    base = Keyword.get(opts, :base, Keyword.get(opts, :base_iri)) |> base_iri(data)
    prefixes = Keyword.get(opts, :prefixes) |> prefix_map(data)
    use_rdf_id = Keyword.get(opts, :use_rdf_id, false)

    with {:ok, root} <- document(data, base, prefixes, use_rdf_id) do
      {:ok, Saxy.encode!(root, version: "1.0", encoding: :utf8)}
    end
  end

  defp base_iri(nil, %Graph{base_iri: base}) when not is_nil(base), do: validate_base_iri(base)
  defp base_iri(nil, _), do: RDF.default_base_iri() |> validate_base_iri()
  defp base_iri(base_iri, _), do: base_iri |> IRI.coerce_base() |> validate_base_iri()

  defp validate_base_iri(nil), do: nil

  defp validate_base_iri(base_iri) do
    uri = base_iri |> to_string() |> URI.parse()
    to_string(%{uri | fragment: nil})
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

  defp document(%Graph{} = graph, base, prefixes, use_rdf_id) do
    with {:ok, descriptions} <- descriptions(graph, base, prefixes, use_rdf_id) do
      {:ok,
       element(
         "rdf:RDF",
         ns_declarations(prefixes, base),
         descriptions
       )}
    end
  end

  defp descriptions(%Graph{} = graph, base, prefixes, use_rdf_id) do
    graph
    |> Graph.descriptions()
    |> map_while_ok(&description(&1, base, prefixes, use_rdf_id))
  end

  defp description(description, base, prefixes, use_rdf_id) do
    {type_node, description} = type_node(description, prefixes)

    with {:ok, predications} <- predications(description, base, prefixes) do
      {:ok,
       element(
         type_node || "rdf:Description",
         [description_id(description.subject, base, use_rdf_id)],
         predications
       )}
    end
  end

  defp type_node(description, prefixes) do
    description
    |> Description.get(RDF.type())
    |> List.wrap()
    |> Enum.find_value(fn object ->
      if qname = qname(object, prefixes) do
        {qname, object}
      end
    end)
    |> case do
      nil -> {nil, description}
      {qname, type} -> {qname, Description.delete(description, {RDF.type(), type})}
    end
  end

  defp description_id(%BlankNode{value: bnode}, _base, _) do
    {"rdf:nodeID", bnode}
  end

  defp description_id(%IRI{value: uri}, base, true) do
    case attr_val_uri(uri, base) do
      "#" <> value -> {"rdf:ID", value}
      value -> {"rdf:about", value}
    end
  end

  defp description_id(%IRI{value: uri}, base, false) do
    {"rdf:about", attr_val_uri(uri, base)}
  end

  def predications(description, base, prefixes) do
    flat_map_while_ok(description.predications, fn {predicate, objects} ->
      predications_for_property(predicate, objects, base, prefixes)
    end)
  end

  def predications_for_property(property, objects, base, prefixes) do
    if property_name = qname(property, prefixes) do
      {:ok,
       objects
       |> Map.keys()
       |> Enum.map(&statement(property_name, &1, base, prefixes))}
    else
      {:error,
       %RDF.XML.EncodeError{message: "no namespace declaration for property #{property} found"}}
    end
  end

  defp statement(property_name, %IRI{value: uri}, base, _) do
    element(property_name, [{"rdf:resource", attr_val_uri(uri, base)}], [])
  end

  defp statement(property_name, %BlankNode{value: value}, _base, _) do
    element(property_name, [{"rdf:nodeID", value}], [])
  end

  defp statement(property_name, %Literal{} = literal, base, _) do
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

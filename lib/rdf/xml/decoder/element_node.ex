defmodule RDF.XML.Decoder.ElementNode do
  @moduledoc !"""
             see https://www.w3.org/TR/rdf-syntax-grammar/#section-element-node
             """
  defstruct [
    :name,
    :uri,
    :rdf_attributes,
    :property_attributes,
    :base_uri,
    :ns_declarations,
    :language,
    :li_counter
  ]

  alias RDF.{PrefixMap, Graph, IRI}
  alias RDF.XML.Decoder

  @type t :: %__MODULE__{
          name: String.t(),
          uri: RDF.IRI.t(),
          rdf_attributes: %{atom => any},
          property_attributes: %{RDF.IRI.t() => any},
          base_uri: String.t() | nil,
          ns_declarations: PrefixMap.t(),
          language: String.t() | nil,
          li_counter: pos_integer
        }

  def new(name, attributes, parent_element, graph) do
    with {:ok, attributes, ns_declarations, base_uri, language} <-
           extract_xml_namespaces(attributes, parent_element, graph),
         {:ok, base_uri} <- normalize_base_uri(base_uri),
         {:ok, uri} <- qname_to_iri(name, ns_declarations),
         {:ok, rdf_attributes, property_attributes, _} <-
           attributes(attributes, ns_declarations, base_uri) do
      {:ok,
       %__MODULE__{
         name: name,
         uri: uri,
         rdf_attributes: rdf_attributes,
         property_attributes: property_attributes,
         ns_declarations: ns_declarations,
         base_uri: base_uri,
         language: language,
         li_counter: 1
       }}
    end
  end

  def update_name(element, name) do
    case qname_to_iri(name, element.ns_declarations) do
      {:ok, uri} ->
        %{
          element
          | name: name,
            uri: uri
        }
    end
  end

  @doc false
  def normalize_base_uri(base_uri = "http" <> _) do
    case String.split(base_uri, "#") do
      [base_uri] -> {:ok, base_uri}
      [base_uri, _fragment] -> {:ok, base_uri}
      _ -> {:error, %RDF.XML.ParseError{message: "invalid base URI: #{base_uri}"}}
    end
  end

  def normalize_base_uri(base_uri), do: {:ok, base_uri}

  defp extract_xml_namespaces(attributes, nil, graph) do
    extract_xml_namespaces(
      attributes,
      PrefixMap.new(),
      to_string(Graph.base_iri(graph)),
      graph
    )
  end

  defp extract_xml_namespaces(attributes, parent_element, graph) do
    extract_xml_namespaces(
      attributes,
      parent_element.ns_declarations,
      parent_element.base_uri,
      graph
    )
  end

  defp extract_xml_namespaces(attributes, parent_ns_declarations, parent_base_uri, _graph) do
    Enum.reduce_while(attributes, {:ok, %{}, parent_ns_declarations, parent_base_uri, nil}, fn
      {"xml:lang", value}, {:ok, attrs, ns_declarations, base_uri, _} ->
        {:cont, {:ok, attrs, ns_declarations, base_uri, value}}

      {"xml:base", value}, {:ok, attrs, ns_declarations, _, language} ->
        {:cont, {:ok, attrs, ns_declarations, value, language}}

      {"xmlns:" <> prefix, value}, {:ok, attrs, ns_declarations, base_uri, language} ->
        {:cont, {:ok, attrs, PrefixMap.put(ns_declarations, prefix, value), base_uri, language}}

      {"xmlns", value}, {:ok, attrs, ns_declarations, base_uri, language} ->
        {:cont, {:ok, attrs, PrefixMap.put(ns_declarations, nil, value), base_uri, language}}

      {name, value}, {:ok, attrs, ns_declarations, base_uri, language} ->
        {:cont, {:ok, Map.put(attrs, name, value), ns_declarations, base_uri, language}}
    end)
  end

  @exclusive_attributes ~w[node_id about id]a

  defp attributes(attributes, ns_declarations, base_uri) do
    Enum.reduce_while(attributes, {:ok, %{}, %{}, false}, fn
      attribute, {:ok, rdf_attributes, property_attrs, excl_attr_present} ->
        case attribute(attribute, ns_declarations, base_uri) do
          {_name, {:error, error}} ->
            {:halt, {:error, error}}

          {_, :ignore} ->
            {:cont, {:ok, rdf_attributes, property_attrs, excl_attr_present}}

          {name, value} when is_atom(name) ->
            excl_attr = name in @exclusive_attributes

            if excl_attr_present and excl_attr do
              {:halt,
               {:error,
                %RDF.XML.ParseError{message: "rdf:nodeID can't be used with rdf:ID and rdf:about"}}}
            else
              {:cont,
               {:ok, Map.put(rdf_attributes, name, value), property_attrs,
                excl_attr_present || excl_attr}}
            end

          {name, value} ->
            {:cont,
             {:ok, rdf_attributes, Map.put(property_attrs, name, value), excl_attr_present}}
        end
    end)
  end

  defp attribute({"rdf:ID", value}, _, base), do: {:id, rdf_id(value, base)}

  defp attribute({"rdf:nodeID", value}, _, _) do
    {:node_id,
     with {:ok, name} <- nc_name(value) do
       name
     end}
  end

  defp attribute({"rdf:about", value}, ns, base), do: {:about, uri_reference(value, ns, base)}

  defp attribute({"rdf:resource", value}, ns, base),
    do: {:resource, uri_reference(value, ns, base)}

  defp attribute({"rdf:datatype", value}, ns, base),
    do: {:datatype, uri_reference(value, ns, base)}

  defp attribute({"rdf:parseType", "Literal"}, _, _), do: {:parseLiteral, true}
  defp attribute({"rdf:parseType", "Resource"}, _, _), do: {:parseResource, true}
  defp attribute({"rdf:parseType", "Collection"}, _, _), do: {:parseCollection, true}
  defp attribute({"rdf:parseType", value}, _, _), do: {:parseOther, value}

  ~w[rdf:li rdf:RDF rdf:Description]
  |> Enum.each(fn term ->
    defp attribute({unquote(term), _}, _, _) do
      {unquote(term),
       {:error,
        %RDF.XML.ParseError{message: "#{unquote(term)} is not allowed as as an attribute"}}}
    end
  end)

  Enum.each(Decoder.old_terms(), fn term ->
    defp attribute({unquote(term), _}, _, _) do
      {unquote(term),
       {:error, %RDF.XML.ParseError{message: "#{unquote(term)} not supported in RDF/XML 1.1"}}}
    end
  end)

  defp attribute({property_attribute_name, value}, ns, _base) do
    case qname_to_iri(property_attribute_name, ns) do
      {:ok, property_attribute_uri} ->
        {property_attribute_uri, value}

      {:error, _} ->
        # Unrecognized attributes in the xml namespace should be ignored.
        {property_attribute_name, :ignore}
    end
  end

  @doc false
  def uri_reference(value, _ns_decl, base) do
    if IRI.absolute?(value) do
      RDF.iri(value)
    else
      IRI.absolute(value, base)
    end
  end

  defp rdf_id(value, nil) do
    {:error,
     %RDF.XML.ParseError{
       message: "use of rdf:ID without a base URI #{value}",
       help:
         "specify one in the RDF/XML document or provide one on the decoder call with the :base opt"
     }}
  end

  defp rdf_id(value, base) do
    with {:ok, name} <- nc_name(value) do
      base <> "#" <> name
    end
  end

  defp qname_to_iri(name, ns_declarations) do
    cond do
      iri = PrefixMap.prefixed_name_to_iri(ns_declarations, name) ->
        {:ok, iri}

      iri = PrefixMap.prefixed_name_to_iri(ns_declarations, ":" <> name) ->
        {:ok, iri}

      true ->
        {:error,
         %RDF.XML.ParseError{
           message: "can't resolve name #{name} to URI reference",
           help: "provide a xmlns declaration"
         }}
    end
  end

  defp nc_name(name) do
    # TODO: NCNames are actually more restrictive; see https://www.w3.org/TR/REC-xml-names/#NT-NCName
    if String.match?(name, ~r/^[a-zA-Z_]/) and not String.contains?(name, ~w[: /]) do
      {:ok, name}
    else
      {:error, %RDF.XML.ParseError{message: "invalid NCName #{name}"}}
    end
  end
end

defmodule RDF.XML.Encoder do
  @moduledoc """
  An encoder for RDF/XML serializations of RDF.ex data structures.

  As for all encoders of `RDF.Serialization.Format`s, you normally won't use these
  functions directly, but via one of the `write_` functions on the `RDF.XML` format
  module or the generic `RDF.Serialization` module.


  ## Options

  - `:base`: : Allows to specify the base URI to be used for a `xml:base` declaration.
    If not specified the one from the given graph is used or if there is also none
    specified for the graph the `RDF.default_base_iri/0`.
  - `:prefixes`: Allows to specify the prefixes to be used as a `RDF.PrefixMap` or
    anything from which a `RDF.PrefixMap` can be created with `RDF.PrefixMap.new/1`.
    If not specified the ones from the given graph are used or if these are also not
    present the `RDF.default_prefixes/0`.
  - `:implicit_base`: Allows to specify that the used base URI should not be encoded
    in the generated serialization (default: `false`).
  - `:use_rdf_id`: Allows to determine if `rdf:ID` should be used when possible.
     You can either provide a boolean value or a function which should return a boolean
     value for a given `RDF.Description`. (default: `false`)
  - `:xml_declaration`: Allows to specify the XML declaration. Possible values:
    - `true` (default): produces the default `<?xml version="1.0" encoding="utf-8"?>` declaration
    - `false`: omits the XML declaration
    - any value supported for `prolog` argument of `Saxy.encode!/2`
      (only available on `encode/2`, not on `stream/2`)
  - `:producer`: This option allows you to provide a producer function, which will get
    the input data (usually a `RDF.Graph`) and should produce a stream of the descriptions
    to be encoded. This allows you to control the order of the descriptions, apply filters
    etc.

          iex> RDF.Graph.new([
          ...>   EX.S1 |> EX.p1(EX.O1),
          ...>   EX.S2 |> EX.p2(EX.O2),
          ...> ])
          ...> |> RDF.XML.write_string!(
          ...>     prefixes: [ex: EX],
          ...>     producer: fn graph ->
          ...>       {first, rest} = RDF.Graph.pop(graph, EX.S2)
          ...>       Stream.concat([first], RDF.Graph.descriptions(rest))
          ...>     end)
          ~S(<?xml version="1.0" encoding="utf-8"?><rdf:RDF xmlns:ex="http://example.com/">\
  <rdf:Description rdf:about="http://example.com/S2"><ex:p2 rdf:resource="http://example.com/O2"/></rdf:Description>\
  <rdf:Description rdf:about="http://example.com/S1"><ex:p1 rdf:resource="http://example.com/O1"/></rdf:Description>\
  </rdf:RDF>)

  """

  use RDF.Serialization.Encoder

  alias RDF.{Description, Graph, Dataset, IRI, BlankNode, Literal, LangString, XSD, PrefixMap}
  import RDF.Utils
  import Saxy.XML

  @doc """
  Encodes the given RDF `data` structure to an RDF/XML string.

  The result is returned in an `:ok` tuple or an `:error` tuple in case of an error.

  For a description of the available options see the [module documentation](`RDF.XML.Encoder`).
  """
  @impl RDF.Serialization.Encoder
  @spec encode(Graph.t(), keyword) :: {:ok, String.t()} | {:error, any}
  def encode(data, opts \\ []) do
    base = Keyword.get(opts, :base, Keyword.get(opts, :base_iri)) |> base_iri(data)
    prefixes = Keyword.get(opts, :prefixes) |> prefix_map(data)
    use_rdf_id = Keyword.get(opts, :use_rdf_id) || false

    xml_declaration =
      case Keyword.get(opts, :xml_declaration, true) do
        true -> [version: "1.0", encoding: :utf8]
        false -> nil
        xml_declaration when is_list(xml_declaration) -> xml_declaration
      end

    with {:ok, root} <- document(data, base, prefixes, use_rdf_id, opts) do
      {:ok, Saxy.encode!(root, xml_declaration)}
    end
  end

  @doc """
  Encodes the given RDF `data` structure to an RDF/XML stream.

  By default, the RDF/XML stream will emit single line strings for each of the
  descriptions in the given `data`. But you can also receive the serialized RDF/XML
  description as IO lists aka iodata by setting the `:mode` option to `:iodata`.

  For a description of the other available options see the [module documentation](`RDF.XML.Encoder`).
  """
  @impl RDF.Serialization.Encoder
  @spec stream(Graph.t(), keyword) :: Enumerable.t()
  def stream(data, opts \\ []) do
    base = Keyword.get(opts, :base, Keyword.get(opts, :base_iri)) |> base_iri(data)
    prefixes = Keyword.get(opts, :prefixes) |> prefix_map(data)
    use_rdf_id = Keyword.get(opts, :use_rdf_id, false)
    stream_mode = Keyword.get(opts, :mode, :string)
    input = input(data, opts)

    {rdf_close, rdf_open} =
      Saxy.encode_to_iodata!(
        {"rdf:RDF", ns_declarations(prefixes, base, implicit_base(opts)), [{:characters, "\n"}]}
      )
      |> List.pop_at(-1)

    {rdf_close, rdf_open} =
      if stream_mode == :string do
        {IO.iodata_to_binary(rdf_close), IO.iodata_to_binary(rdf_open)}
      else
        {rdf_close, rdf_open}
      end

    Stream.concat([
      if(Keyword.get(opts, :xml_declaration, true),
        do: [~s[<?xml version="1.0" encoding="utf-8"?>\n]],
        else: []
      ),
      [rdf_open],
      description_stream(input, base, prefixes, use_rdf_id, stream_mode),
      [rdf_close]
    ])
  end

  defp input(data, opts) do
    case Keyword.get(opts, :producer) do
      fun when is_function(fun) -> fun.(data)
      nil -> data
    end
  end

  defp implicit_base(opts) do
    Keyword.get(opts, :implicit_base, false)
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

  defp ns_declarations(prefixes, nil, _) do
    prefixes
    |> PrefixMap.to_sorted_list()
    |> Enum.map(fn
      {nil, namespace} -> {"xmlns", to_string(namespace)}
      {prefix, namespace} -> {"xmlns:#{prefix}", to_string(namespace)}
    end)
  end

  defp ns_declarations(prefixes, _, true) do
    ns_declarations(prefixes, nil, true)
  end

  defp ns_declarations(prefixes, base, implicit_base) do
    [{"xml:base", to_string(base)} | ns_declarations(prefixes, nil, implicit_base)]
  end

  defp document(graph, base, prefixes, use_rdf_id, opts) do
    with {:ok, descriptions} <-
           graph
           |> input(opts)
           |> descriptions(base, prefixes, use_rdf_id) do
      {:ok,
       element(
         "rdf:RDF",
         ns_declarations(prefixes, base, implicit_base(opts)),
         descriptions
       )}
    end
  end

  defp descriptions(%Graph{} = graph, base, prefixes, use_rdf_id) do
    graph
    |> Graph.descriptions()
    |> descriptions(base, prefixes, use_rdf_id)
  end

  defp descriptions(input, base, prefixes, use_rdf_id) do
    map_while_ok(input, &description(&1, base, prefixes, use_rdf_id))
  end

  defp description_stream(%Graph{} = graph, base, prefixes, use_rdf_id, stream_mode) do
    graph
    |> Graph.descriptions()
    |> description_stream(base, prefixes, use_rdf_id, stream_mode)
  end

  @dialyzer {:nowarn_function, description_stream: 5}
  defp description_stream(input, base, prefixes, use_rdf_id, stream_mode) do
    Stream.map(input, fn description ->
      case description(description, base, prefixes, use_rdf_id) do
        {:ok, simple_form} when stream_mode == :string ->
          Saxy.encode!(simple_form) <> "\n"

        {:ok, simple_form} when stream_mode == :iodata ->
          [Saxy.encode_to_iodata!(simple_form) | "\n"]

        {:error, error} ->
          raise error
      end
    end)
  end

  defp description(%Description{} = description, base, prefixes, use_rdf_id) do
    {type_node, stripped_description} = type_node(description, prefixes)

    with {:ok, predications} <- predications(stripped_description, base, prefixes) do
      {:ok,
       element(
         type_node || "rdf:Description",
         [description_id(description.subject, base, use_rdf_id, description)],
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

  defp description_id(%BlankNode{value: bnode}, _base, _, _) do
    {"rdf:nodeID", bnode}
  end

  defp description_id(%IRI{} = iri, base, fun, description) when is_function(fun) do
    description_id(iri, base, fun.(description), description)
  end

  defp description_id(%IRI{} = iri, base, true, _) do
    case attr_val_uri(iri, base) do
      "#" <> value -> {"rdf:ID", value}
      value -> {"rdf:about", value}
    end
  end

  defp description_id(%IRI{} = iri, base, false, _) do
    {"rdf:about", attr_val_uri(iri, base)}
  end

  defp predications(description, base, prefixes) do
    flat_map_while_ok(description.predications, fn {predicate, objects} ->
      predications_for_property(predicate, objects, base, prefixes)
    end)
  end

  defp predications_for_property(property, objects, base, prefixes) do
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

  defp statement(property_name, %IRI{} = iri, base, _) do
    element(property_name, [{"rdf:resource", attr_val_uri(iri, base)}], [])
  end

  defp statement(property_name, %BlankNode{value: value}, _base, _) do
    element(property_name, [{"rdf:nodeID", value}], [])
  end

  @xml_literal IRI.to_string(RDF.XMLLiteral)

  defp statement(property_name, %Literal{literal: %{datatype: @xml_literal}} = literal, _, _) do
    element(
      property_name,
      [{"rdf:parseType", "Literal"}],
      Literal.lexical(literal)
    )
  end

  defp statement(property_name, %Literal{} = literal, base, _) do
    element(
      property_name,
      literal_attributes(literal, base),
      [{:characters, Literal.lexical(literal)}]
    )
  end

  defp literal_attributes(%Literal{literal: %LangString{language: language}}, _),
    do: [{"xml:lang", language}]

  defp literal_attributes(%Literal{literal: %XSD.String{}}, _), do: []

  defp literal_attributes(%Literal{literal: %datatype{}}, base),
    do: [{"rdf:datatype", datatype.id() |> attr_val_uri(base)}]

  defp literal_attributes(_, _), do: []

  defp attr_val_uri(iri, nil), do: iri
  defp attr_val_uri(%IRI{value: uri}, base), do: attr_val_uri(uri, base)

  defp attr_val_uri(iri, base) do
    String.replace_prefix(iri, base, "")
  end

  defp qname(iri, prefixes) do
    case PrefixMap.prefixed_name(prefixes, iri) do
      nil -> nil
      ":" <> name -> name
      name -> name
    end
  end
end

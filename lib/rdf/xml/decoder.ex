defmodule RDF.XML.Decoder do
  @moduledoc """
  A decoder for RDF/XML serializations from strings or streams to `RDF.Graph`s.
  """

  use RDF.Serialization.Decoder

  alias RDF.XML.Decoder.{Grammar, EventHandler}
  alias RDF.Graph

  @core_syntax_terms ~w[rdf:RDF rdf:ID rdf:about rdf:parseType rdf:resource rdf:nodeID rdf:datatype]
  @old_terms ~w[rdf:aboutEach rdf:aboutEachPrefix rdf:bagID]

  @doc false
  def core_syntax_terms, do: @core_syntax_terms

  @doc false
  def old_terms, do: @old_terms

  @doc """
  Decodes an RDF/XML string or stream to a `RDF.Graph`.

  The result is returned in an `:ok` tuple or an `:error` tuple in case of an error.

  As for all decoders of `RDF.Serialization.Format`s, you normally won't use this
  function directly, but via one of the `read_` functions on the `RDF.XML` format module.

  ## Options

  Apart from the usual `:base` option of most RDF.ex serialization decoders,
  the following options are supported:

  - `:bnode_prefix`: allows to specify the prefix which auto-generated blank nodes
    should get (default: `"b"`)

  """
  @impl RDF.Serialization.Decoder
  @spec decode(String.t() | Enumerable.t(), keyword) :: {:ok, Graph.t()} | {:error, any}
  def decode(string, opts \\ []),
    do: do_decode(&Saxy.parse_string/3, string, opts)

  @impl RDF.Serialization.Decoder
  @spec decode_from_stream(Enumerable.t(), keyword) :: RDF.Graph.t() | RDF.Dataset.t()
  def decode_from_stream(stream, opts \\ []),
    do: do_decode(&Saxy.parse_stream/3, stream, opts)

  defp do_decode(decoder_fun, input, opts) do
    with {:ok, {_, graph, _, _}} <-
           decoder_fun.(
             input,
             EventHandler,
             Grammar.initial_state(opts)
           ) do
      {:ok, graph}
    else
      {:halt, error, _} -> error
      error -> error
    end
  end
end

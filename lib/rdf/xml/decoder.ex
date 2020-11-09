defmodule RDF.XML.Decoder do
  @moduledoc """
  A decoder for RDF/XML serializations from strings or streams to `RDF.Graph`s.

  As for all decoders of `RDF.Serialization.Format`s, you normally won't use these
  functions directly, but via one of the `read_` functions on the `RDF.XML` format
  module or the generic `RDF.Serialization` module.


  ## Options

  Apart from the usual `:base` option of most RDF.ex serialization decoders,
  the following options are supported:

  - `:bnode_prefix`: allows to specify the prefix which auto-generated blank nodes
    should get (default: `"b"`)

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
  Decodes an RDF/XML string to a `RDF.Graph`.

  The result is returned in an `:ok` tuple or an `:error` tuple in case of an error.

  For a description of the available options see the [module documentation](`RDF.XML.Encoder`).
  """
  @impl RDF.Serialization.Decoder
  @spec decode(String.t() | Enumerable.t(), keyword) :: {:ok, Graph.t()} | {:error, any}
  def decode(string, opts \\ []),
    do: do_decode(&Saxy.parse_string/3, string, opts)

  @doc """
  Decodes an RDF/XML stream to a `RDF.Graph`.

  For a description of the available options see the [module documentation](`RDF.XML.Encoder`).
  """
  @impl RDF.Serialization.Decoder
  @spec decode_from_stream(Enumerable.t(), keyword) :: {:ok, Graph.t()} | {:error, any}
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

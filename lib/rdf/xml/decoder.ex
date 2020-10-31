defmodule RDF.XML.Decoder do
  use RDF.Serialization.Decoder

  alias RDF.XML.Decoder.{Grammar, EventHandler}
  alias RDF.Graph

  @core_syntax_terms ~w[rdf:RDF rdf:ID rdf:about rdf:parseType rdf:resource rdf:nodeID rdf:datatype]
  @old_terms ~w[rdf:aboutEach rdf:aboutEachPrefix rdf:bagID]

  @doc false
  def core_syntax_terms, do: @core_syntax_terms

  @doc false
  def old_terms, do: @old_terms

  @impl RDF.Serialization.Decoder
  @spec decode(String.t() | Enumerable.t(), keyword) :: {:ok, Graph.t()} | {:error, any}
  def decode(input, opts \\ [])

  def decode(string, opts) when is_binary(string),
    do: do_decode(&Saxy.parse_string/3, string, opts)

  def decode(stream, opts),
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

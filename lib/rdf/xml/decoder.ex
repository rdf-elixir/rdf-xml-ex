defmodule RDF.XML.Decoder do
  @moduledoc false

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
  @spec decode(String.t(), keyword) :: {:ok, Graph.t()} | {:error, any}
  def decode(content, opts \\ [])

  def decode(content, opts) do
    with {:ok, {_, graph, _}} <-
           Saxy.parse_string(
             content,
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

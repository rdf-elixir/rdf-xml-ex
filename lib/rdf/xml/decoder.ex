defmodule RDF.XML.Decoder do
  @moduledoc false

  use RDF.Serialization.Decoder

  alias RDF.XML.Decoder.{Grammar, EventHandler}
  alias RDF.Graph

  @impl RDF.Serialization.Decoder
  @spec decode(String.t(), keyword) :: {:ok, Graph.t()} | {:error, any}
  def decode(content, opts \\ [])

  def decode(content, opts) do
    with {:ok, {_, graph}} <-
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

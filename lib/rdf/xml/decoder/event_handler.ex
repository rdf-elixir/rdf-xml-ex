defmodule RDF.XML.Decoder.EventHandler do
  @moduledoc false

  @behaviour Saxy.Handler

  alias RDF.XML.Decoder.Grammar

  def handle_event(:start_document, _prolog, state), do: {:ok, state}
  def handle_event(:end_document, _data, state), do: {:ok, state}

  def handle_event(event_type, data, state) do
    case Grammar.apply_production(event_type, data, state) do
      {:ok, state} -> {:ok, state}
      error -> {:halt, error}
    end
  end
end

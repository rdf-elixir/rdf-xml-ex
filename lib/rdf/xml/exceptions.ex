defmodule RDF.XML.ParseError do
  defexception [:message, :help]

  def message(%{message: message, help: nil}), do: message
  def message(%{message: message, help: help}), do: message <> "; " <> help
end

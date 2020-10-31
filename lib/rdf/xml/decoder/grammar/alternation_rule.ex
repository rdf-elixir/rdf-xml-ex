defmodule RDF.XML.Decoder.Grammar.AlternationRule do
  @moduledoc false

  alias RDF.XML.Decoder.Grammar.ControlRule

  defdelegate apply(new_cxt, new_element, graph, bnodes), to: ControlRule

  defmacro __using__(opts) do
    quote do
      use ControlRule, unquote(opts)

      def type, do: unquote(__MODULE__)

      def result_elements(%__MODULE__{children: [element]}), do: element

      def cascaded_end?, do: true
    end
  end
end

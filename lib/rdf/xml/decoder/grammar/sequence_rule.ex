defmodule RDF.XML.Decoder.Grammar.SequenceRule do
  alias RDF.XML.Decoder.Grammar.ControlRule

  defdelegate apply(new_cxt, new_element, graph, bnodes), to: ControlRule

  defmacro __using__(opts) do
    quote do
      use ControlRule, unquote(opts)

      def type, do: unquote(__MODULE__)

      def result_elements(%__MODULE__{children: elements}), do: elements

      def cascaded_end?, do: false

      # We assume every SequenceRule has just one rule as production
      def select_production(cxt, _), do: cxt.production
    end
  end
end

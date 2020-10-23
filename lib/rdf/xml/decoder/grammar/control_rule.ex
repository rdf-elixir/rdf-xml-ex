defmodule RDF.XML.Decoder.Grammar.ControlRule do
  alias RDF.XML.Decoder.Grammar.Rule

  defmacro __using__(opts) do
    quote do
      use Rule, unquote(opts)

      def element_rule?, do: false

      defdelegate element_cxt(cxt), to: Rule, as: :parent_element_cxt
    end
  end
end

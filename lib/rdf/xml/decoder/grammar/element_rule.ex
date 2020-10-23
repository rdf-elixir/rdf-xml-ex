defmodule RDF.XML.Decoder.Grammar.ElementRule do
  alias RDF.XML.Decoder.Grammar.{Rule, ElementNode}

  @callback conform?(element :: ElementNode.t()) :: boolean

  @default_attributes [:element]

  defmacro __using__(opts) do
    opts =
      opts
      |> Keyword.update(:struct, @default_attributes, fn struct ->
        @default_attributes ++ struct
      end)

    quote do
      @behaviour unquote(__MODULE__)

      use Rule, unquote(opts)

      @impl true
      def conform?(element_node), do: true

      defoverridable unquote(__MODULE__)

      def type, do: unquote(__MODULE__)

      def element_rule?, do: true

      def element_cxt(cxt), do: cxt

      def cascaded_end?, do: false

      # We assume every ElementRule has just one rule as production
      def select_production(cxt, _), do: cxt.production

      defdelegate parent_element_cxt(cxt), to: Rule
      defdelegate parent(cxt), to: Rule, as: :parent_element_cxt
    end
  end
end

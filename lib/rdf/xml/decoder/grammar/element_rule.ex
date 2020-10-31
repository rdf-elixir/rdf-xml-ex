defmodule RDF.XML.Decoder.Grammar.ElementRule do
  @moduledoc false

  alias RDF.XML.Decoder.Grammar.Rule
  alias RDF.XML.Decoder.ElementNode

  @callback at_start(Rule.context(), RDF.Graph.t(), RDF.BlankNode.Increment.state()) ::
              {:ok, Rule.context(), RDF.BlankNode.Increment.state()} | {:error, any}

  @callback conform?(element :: ElementNode.t()) :: boolean

  @default_attributes [:element]

  def apply(%rule{} = new_cxt, element, graph, bnodes) do
    if rule.conform?(element) do
      with {:ok, new_cxt, new_bnodes} <- rule.at_start(new_cxt, graph, bnodes) do
        {:ok, {new_cxt, new_bnodes}}
      end
    else
      {:error,
       %RDF.XML.ParseError{
         message: "element #{element.name} is not conform with rule #{rule}"
       }}
    end
  end

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
      def at_start(cxt, _, bnodes), do: {:ok, cxt, bnodes}

      @impl true
      def conform?(element_node), do: true

      defoverridable unquote(__MODULE__)

      def type, do: unquote(__MODULE__)

      def element_rule?, do: true

      def element_cxt(cxt), do: cxt

      def result_elements(cxt), do: cxt

      def cascaded_end?, do: false

      defdelegate parent_element_cxt(cxt), to: Rule
      defdelegate parent(cxt), to: Rule, as: :parent_element_cxt
    end
  end
end

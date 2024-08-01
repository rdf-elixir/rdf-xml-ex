defmodule RDF.XML.Decoder.Grammar.ControlRule do
  @moduledoc false

  alias RDF.XML.Decoder.Grammar.Rule
  alias RDF.XML.Decoder.ElementNode

  @callback at_start(
              ElementNode.t(),
              Rule.context(),
              RDF.Graph.t(),
              RDF.BlankNode.Generator.Increment.t()
            ) ::
              {:ok, ElementNode.t(), Rule.context(), RDF.BlankNode.Generator.Increment.t()}
              | {:error, any}

  def apply(%rule{} = new_cxt, new_element, graph, bnodes) do
    with {:ok, new_element, new_cxt, new_bnodes} <-
           rule.at_start(new_element, new_cxt, graph, bnodes) do
      Rule.apply_production(new_cxt, new_element, graph, new_bnodes)
    end
  end

  defmacro __using__(opts) do
    quote do
      @behaviour unquote(__MODULE__)
      use Rule, unquote(opts)

      @impl true
      def at_start(element, cxt, _, bnodes), do: {:ok, element, cxt, bnodes}

      defoverridable unquote(__MODULE__)

      def element_rule?, do: false

      defdelegate element_cxt(cxt), to: Rule, as: :parent_element_cxt
    end
  end
end

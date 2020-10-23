defmodule RDF.XML.Decoder.Grammar.AlternationRule do
  alias RDF.XML.Decoder.Grammar.{Rule, ControlRule}

  @callback select_production(Rule.context(), ElementNode.t()) :: Rule.t() | [Rule.t()]

  defmacro __using__(opts) do
    quote do
      @behaviour unquote(__MODULE__)

      use ControlRule, unquote(opts)

      @impl true
      # This assumes the production of AlternationRules consists of a list solely of ElementRules.
      def select_production(cxt, element) do
        cxt.production
        |> Enum.filter(fn rule -> rule.conform?(element) end)
        |> case do
          [] -> nil
          [rule] -> rule
          rules -> rules
        end
      end

      defoverridable unquote(__MODULE__)

      def type, do: unquote(__MODULE__)

      def cascaded_end?, do: true
    end
  end
end

defmodule RDF.XML.Decoder.Grammar.Rule do
  alias RDF.XML.Decoder.ElementNode
  import RDF.Utils

  @type t :: module
  @type context :: %{:__struct__ => t(), :children => any(), optional(atom()) => any()}

  @callback at_start(context(), Graph.t()) :: {:ok, context()} | {:error, any}

  # should return the result which should be set on the children field of the parent
  @callback at_end(context(), Graph.t()) ::
              {:ok, result :: any, Graph.t()} | {:error, any}

  # should return update Rule struct
  @callback characters(characters :: String.t(), context()) ::
              {:ok, t} | {:error, any}

  @default_attributes [:parent_cxt, :children]

  def parent_element_cxt(%{parent_cxt: nil}), do: nil

  def parent_element_cxt(%{parent_cxt: %parent_rule{} = parent_cxt}) do
    if parent_rule.element_rule? do
      parent_cxt
    else
      parent_element_cxt(parent_cxt)
    end
  end

  def apply_production(%rule{} = cxt, new_element, graph) do
    apply_production(cxt, rule.select_production(rule, new_element), new_element, graph)
  end

  def apply_production(%rule{} = cxt, nil, new_element, _) do
    # TODO: proper ParseError
    {:error, "element #{inspect(new_element)} is not applicable in #{rule.element(cxt).name}"}
  end

  def apply_production(cxt, alt_rules, new_element, graph) when is_list(alt_rules) do
    map_while_ok(alt_rules, &apply_production(cxt, &1, new_element, graph))
  end

  def apply_production(cxt, next_rule, new_element, graph) do
    with {:ok, next_cxt} <-
           cxt
           |> next_rule.new(element: new_element)
           |> next_rule.at_start(graph) do
      if next_rule.element_rule? do
        {:ok, next_cxt}
      else
        apply_production(next_cxt, new_element, graph)
      end
    end
  end

  def end_element(%rule{} = cxt, name, graph, element_deleted \\ false) do
    with {:ok, result, graph} <- rule.at_end(cxt, graph) do
      case cxt.parent_cxt do
        nil ->
          {:ok, nil, graph}

        %parent_rule{} = parent_cxt ->
          cascaded_end(
            element_deleted || rule.element_rule?,
            parent_rule.cascaded_end?,
            update_children(parent_cxt, result),
            name,
            graph
          )
      end
    end
  end

  defp cascaded_end(element_deleted, cascaded_end_rule, cxt, name, graph)
  defp cascaded_end(false, _, cxt, name, graph), do: end_element(cxt, name, graph, false)
  defp cascaded_end(true, true, cxt, name, graph), do: end_element(cxt, name, graph, true)
  defp cascaded_end(true, false, cxt, name, graph), do: {:ok, cxt, graph}

  defp update_children(%{children: nil} = cxt, result), do: %{cxt | children: [result]}
  defp update_children(cxt, result), do: %{cxt | children: [result | cxt.children]}

  defmodule Shared do
    alias RDF.{Description, Literal, LangString}

    @rdf_type Elixir.RDF.type()

    def resolve(string, element) do
      ElementNode.uri_reference(string, element.ns_declarations, element.base_uri)
    end

    def ws?(characters) do
      # TODO: This seems to recognize more characters as whitespace " \t\n\r\v..."
      #       according to the spec: space (#x20) characters, carriage returns, line feeds, or tabs
      String.trim(characters) == ""
    end

    def description_from_property_attrs(cxt, %Description{} = description) do
      Enum.reduce(cxt.element.property_attributes, description, fn
        {@rdf_type, value}, desc ->
          Description.add(desc, {@rdf_type, resolve(value, cxt.element)})

        {uri, value}, desc ->
          Description.add(
            desc,
            {
              uri,
              if language = cxt.element.language do
                LangString.new(value, language: language)
              else
                Literal.new(value)
              end
            }
          )
      end)
    end

    def description_from_property_attrs(cxt, subject) do
      description_from_property_attrs(cxt, Description.new(subject))
    end
  end

  defmacro __using__(opts) do
    no_children = Keyword.get(opts, :no_children, false)
    struct = Keyword.get(opts, :struct, []) ++ @default_attributes

    production = Keyword.get(opts, :production)

    quote do
      @behaviour unquote(__MODULE__)

      import unquote(__MODULE__).Shared

      defstruct unquote(struct)

      def new(parent_cxt, fields \\ []) do
        %{struct(__MODULE__, fields) | parent_cxt: parent_cxt}
      end

      @production unquote(production)
      def production, do: @production

      def no_children?, do: unquote(no_children)

      @impl true
      def at_start(cxt, _), do: {:ok, cxt}

      @impl true
      def characters(characters, cxt) do
        if ws?(characters) do
          {:ok, cxt}
        else
          # TODO: proper ParseError
          {:error, "unexpected characters in element #{inspect(cxt)}: #{characters}"}
        end
      end

      defoverridable unquote(__MODULE__)

      def element(cxt) do
        if element_cxt = element_cxt(cxt) do
          element_cxt.element
        end
      end
    end
  end

  # only for debugging purposes
  def call_stack(nil), do: []

  def call_stack(%rule{parent_cxt: parent, element: element}),
    do: [{rule, element.name} | call_stack(parent)]

  def call_stack(%rule{parent_cxt: parent}), do: [rule | call_stack(parent)]
end

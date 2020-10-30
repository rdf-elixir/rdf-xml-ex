defmodule RDF.XML.Decoder.Grammar.Rule do
  alias RDF.XML.Decoder.ElementNode

  @type t :: module
  @type context :: %{:__struct__ => t(), :children => any(), optional(atom()) => any()}

  # should return the result which should be set on the children field of the parent
  @callback at_end(context(), RDF.Graph.t(), RDF.BlankNode.Increment.state()) ::
              {:ok, RDF.Graph.t(), RDF.BlankNode.Increment.state()} | {:error, any}

  # should return update Rule struct
  @callback characters(characters :: String.t(), context()) ::
              {:ok, context} | {:error, any}

  @callback select_production(context(), ElementNode.t()) :: t() | [t()]

  @default_attributes [:parent_cxt, :children]

  def parent_element_cxt(%{parent_cxt: nil}), do: nil

  def parent_element_cxt(%{parent_cxt: %parent_rule{} = parent_cxt}) do
    if parent_rule.element_rule?() do
      parent_cxt
    else
      parent_element_cxt(parent_cxt)
    end
  end

  def apply_production(%rule{} = cxt, new_element, graph, bnodes) do
    apply_production(cxt, rule.select_production(rule, new_element), new_element, graph, bnodes)
  end

  def apply_production(%rule{} = cxt, nil, new_element, _, _) do
    {:error,
     %RDF.XML.ParseError{
       message: "element #{new_element.name} is not applicable in #{rule.element(cxt).name}"
     }}
  end

  def apply_production(cxt, alt_rules, new_element, graph, bnodes) when is_list(alt_rules) do
    alt_rules
    |> Enum.reduce({[], bnodes}, fn rule, {cxts, bnodes} ->
      case apply_production(cxt, rule, new_element, graph, bnodes) do
        {:ok, {cxt, bnodes}} -> {[cxt | cxts], bnodes}
        {:error, _} -> {cxts, bnodes}
      end
    end)
    |> case do
      {[], _} ->
        {:error,
         %RDF.XML.ParseError{message: "no rule matches for alternatives: #{inspect(alt_rules)}"}}

      {[result], bnodes} ->
        {:ok, {result, bnodes}}

      {results, bnodes} ->
        {:ok, {results, bnodes}}
    end
  end

  def apply_production(cxt, next_rule, new_element, graph, bnodes) do
    cxt
    # Note that the new_element becomes only part of the new cxt on ElementRules (:element is not a member of the non-ElementRule-structs)
    |> next_rule.new(element: new_element)
    |> next_rule.type.apply(new_element, graph, bnodes)
  end

  def end_element(%rule{} = cxt, name, graph, bnodes, element_deleted \\ false) do
    with {:ok, graph, new_bnodes} <- rule.at_end(cxt, graph, bnodes) do
      case cxt.parent_cxt do
        nil ->
          {:ok, nil, graph, new_bnodes}

        %parent_rule{} = parent_cxt ->
          cascaded_end(
            element_deleted || rule.element_rule?(),
            parent_rule.cascaded_end?(),
            update_children(parent_cxt, cxt |> rule.result_elements() |> finish()),
            name,
            graph,
            new_bnodes
          )
      end
    end
  end

  defp cascaded_end(element_deleted, cascaded_end_rule, cxt, name, graph, bnodes)

  defp cascaded_end(false, _, cxt, name, graph, bnodes),
    do: end_element(cxt, name, graph, bnodes, false)

  defp cascaded_end(true, true, cxt, name, graph, bnodes),
    do: end_element(cxt, name, graph, bnodes, true)

  defp cascaded_end(true, false, cxt, _name, graph, bnodes), do: {:ok, cxt, graph, bnodes}

  defp update_children(%{children: nil} = cxt, result), do: %{cxt | children: List.wrap(result)}
  # Note, that we're adding the children here in reverse order for performance reasons.
  defp update_children(cxt, result), do: %{cxt | children: [result | cxt.children]}

  def finish(list) when is_list(list), do: list
  def finish(cxt), do: %{cxt | parent_cxt: nil}

  defmodule Shared do
    alias RDF.{Description, BlankNode, Literal, LangString}

    @rdf_type RDF.type()

    def resolve(string, element) do
      ElementNode.uri_reference(string, element.ns_declarations, element.base_uri)
    end

    def generated_blank_node_id(bnodes) do
      BlankNode.Increment.generate(bnodes)
    end

    def bnodeid(value, bnodes) do
      BlankNode.Increment.generate_for(value, bnodes)
    end

    def reify({subject, predicate, object}, id) do
      id
      |> RDF.type(RDF.Statement)
      |> RDF.subject(subject)
      |> RDF.predicate(predicate)
      |> RDF.object(object)
    end

    def ws?(characters) do
      # TODO: This seems to recognize more characters as whitespace " \t\n\r\v..."
      #       according to the spec whitespace are only: space (#x20) characters, carriage returns, line feeds, or tabs
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
      def at_end(_cxt, graph, bnodes) do
        {:ok, graph, bnodes}
      end

      @impl true
      def characters(characters, cxt) do
        if ws?(characters) do
          {:ok, cxt}
        else
          {:error,
           %RDF.XML.ParseError{
             message: "unexpected characters in element #{cxt.element.name}: #{characters}"
           }}
        end
      end

      @impl true
      def select_production(cxt, _), do: cxt.production

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

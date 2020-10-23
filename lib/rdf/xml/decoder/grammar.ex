defmodule RDF.XML.Decoder.Grammar do
  alias RDF.XML.Decoder.Grammar.{Rule, Rules}
  alias RDF.XML.Decoder.ElementNode
  alias RDF.Graph

  @type state :: {Rule.context() | [Rule.context()] | nil, RDF.Graph.t()}

  def initial_state(opts) do
    {Rules.Doc.new(nil), Graph.new(base_iri: initial_base_uri(opts))}
  end

  defp initial_base_uri(opts) do
    opts
    |> Keyword.get(:base, Keyword.get(opts, :base_iri, RDF.default_base_iri()))
    |> ElementNode.normalize_base_uri()
    |> case do
      {:ok, base_uri} -> base_uri
      {:error, error} -> raise error
    end
  end

  @spec apply_production(
          Saxy.Handler.event_name(),
          Saxy.Handler.event_data(),
          state
        ) :: {:ok, state} | {:error, any}
  def apply_production(event_name, event_data, state)

  def apply_production(event_name, event_data, {alt_branches, graph})
      when is_list(alt_branches) do
    alt_branches
    |> Enum.map(&apply_production(event_name, event_data, {&1, graph}))
    |> Enum.group_by(
      fn
        {:ok, state} -> :ok
        {:error, error} -> :stop
      end,
      fn {_, state_or_error} -> state_or_error end
    )
    |> case do
      %{ok: []} ->
        # TODO: proper ParseError
        {:error, "no rule matches"}

      %{ok: [state]} ->
        {:ok, state}

      %{ok: branches} ->
        {
          :ok,
          # This assumes none of the alternative branches produces different graphs.
          # Use this version to temporarily enforce this for tests, but it shouldn't be in the released version for performance reasons.
          # Enum.reduce(branches, {[], nil}, fn
          #   {cxt, graph}, {branches, nil} -> {[cxt | branches], graph}
          #   {cxt, graph}, {branches, graph} -> {[cxt | branches], graph}
          # end)
          Enum.reduce(branches, {[], nil}, fn
            {cxt, graph}, {branches, _} -> {[cxt | branches], graph}
          end)
        }
    end
  end

  def apply_production(:start_element, {name, attributes}, {%current_rule{} = cxt, graph}) do
    with {:ok, element} <-
           ElementNode.new(name, attributes, current_rule.element(cxt), graph),
         {:ok, next_cxt} <-
           Rule.apply_production(cxt, element, graph) do
      {:ok, {next_cxt, graph}}
    end
  end

  def apply_production(:end_element, name, {cxt, graph}) do
    with {:ok, cxt, graph} <- Rule.end_element(cxt, name, graph) do
      {:ok, {cxt, graph}}
    end
  end

  def apply_production(:characters, characters, {%rule{} = cxt, graph}) do
    with {:ok, new_cxt} <- rule.characters(characters, cxt) do
      {:ok, {new_cxt, graph}}
    end
  end
end

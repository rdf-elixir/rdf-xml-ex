defmodule RDF.XML.Decoder.Grammar do
  alias RDF.XML.Decoder.Grammar.{Rule, Rules}
  alias RDF.XML.Decoder.ElementNode
  alias RDF.{Graph, BlankNode}

  @type state :: {
          Rule.context() | [Rule.context()] | nil,
          Graph.t(),
          BlankNode.Increment.state()
        }

  def initial_state(opts) do
    {
      Rules.Doc.new(nil),
      Graph.new(base_iri: initial_base_uri(opts)),
      BlankNode.Increment.init(%{prefix: Keyword.get(opts, :bnode_prefix, "b")})
    }
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

  def apply_production(event_name, event_data, {alt_branches, graph, bnodes})
      when is_list(alt_branches) do
    alt_branches
    |> Enum.map(&apply_production(event_name, event_data, {&1, graph, bnodes}))
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
          # Enum.reduce(branches, {[], nil, nil}, fn
          #   {cxt, graph, bnodes}, {branches, nil, nil} -> {[cxt | branches], graph, bnodes}
          #   {cxt, graph, bnodes}, {branches, graph, bnodes} -> {[cxt | branches], graph, bnodes}
          # end)
          Enum.reduce(branches, {[], nil, nil}, fn
            {cxt, graph, bnodes}, {branches, _, _} -> {[cxt | branches], graph, bnodes}
          end)
        }
    end
  end

  def apply_production(:start_element, {name, attributes}, {%current_rule{} = cxt, graph, bnodes}) do
    with {:ok, element} <-
           ElementNode.new(name, attributes, current_rule.element(cxt), graph),
         {:ok, next_cxt, new_bnodes} <-
           Rule.apply_production(cxt, element, graph, bnodes) do
      {:ok, {next_cxt, graph, new_bnodes}}
    end
  end

  def apply_production(:end_element, name, {cxt, graph, bnodes}) do
    with {:ok, cxt, graph, new_bnodes} <- Rule.end_element(cxt, name, graph, bnodes) do
      {:ok, {cxt, graph, new_bnodes}}
    end
  end

  def apply_production(:characters, characters, {%rule{} = cxt, graph, bnodes}) do
    with {:ok, new_cxt} <- rule.characters(characters, cxt) do
      {:ok, {new_cxt, graph, bnodes}}
    end
  end
end

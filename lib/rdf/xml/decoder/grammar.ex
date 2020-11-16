defmodule RDF.XML.Decoder.Grammar do
  @moduledoc false

  alias RDF.XML.Decoder.Grammar.{Rule, Rules, LiteralRule}
  alias RDF.XML.Decoder.ElementNode
  alias RDF.{Graph, BlankNode}

  @type state :: {
          Rule.context() | [Rule.context()] | nil,
          Graph.t(),
          BlankNode.Increment.state(),
          MapSet.t()
        }

  def initial_state(opts) do
    {
      Rules.Doc.new(nil),
      Graph.new(base_iri: initial_base_uri(opts)),
      BlankNode.Increment.init(%{prefix: Keyword.get(opts, :bnode_prefix, "b")}),
      MapSet.new()
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

  def apply_production(
        :start_element,
        {name, attributes},
        {%rule{} = cxt, graph, bnodes, rdf_ids}
      )
      when rule in [LiteralRule, Rules.ParseTypeLiteralPropertyElt] do
    with {:ok, next_cxt} <- LiteralRule.apply(cxt, name, attributes) do
      {:ok, {next_cxt, graph, bnodes, rdf_ids}}
    end
  end

  def apply_production(:start_element, {name, attributes}, {cxt, graph, bnodes, rdf_ids}) do
    parent_element =
      case cxt do
        [%rule{} = first | _] -> rule.element(first)
        %rule{} = cxt -> rule.element(cxt)
      end

    with {:ok, element} <- ElementNode.new(name, attributes, parent_element, graph),
         {:ok, rdf_ids} <- check_rdf_id(element.rdf_attributes[:id], rdf_ids) do
      apply_production(:start_element, element, {cxt, graph, bnodes, rdf_ids})
    end
  end

  def apply_production(event_name, element, {alt_branches, graph, bnodes, rdf_ids})
      when is_list(alt_branches) do
    alt_branches
    |> Enum.map(&apply_production(event_name, element, {&1, graph, bnodes, rdf_ids}))
    |> Enum.group_by(
      fn
        {:ok, _state} -> :ok
        {:error, _error} -> :stop
      end,
      fn {_, state_or_error} -> state_or_error end
    )
    |> case do
      %{ok: [state]} ->
        {:ok, state}

      %{ok: branches} ->
        {
          :ok,
          # This assumes none of the alternative branches produces different graphs.
          # Use this version to temporarily enforce this for tests, but it shouldn't be in the released version for performance reasons.
          # Enum.reduce(branches, {[], nil, nil, nil}, fn
          #   {cxt, graph, bnodes, rdf_ids}, {branches, nil, nil, nil} ->
          #     {[cxt | branches], graph, bnodes, rdf_ids}
          #   {cxt, graph, bnodes, rdf_ids}, {branches, graph, bnodes, rdf_ids} ->
          #     {[cxt | branches], graph, bnodes, rdf_ids}
          # end)
          Enum.reduce(branches, {[], nil, nil, nil}, fn
            {cxt, graph, bnodes, rdf_ids}, {branches, _, _, _} ->
              {[cxt | branches], graph, bnodes, rdf_ids}
          end)
        }

      %{} ->
        {:error, %RDF.XML.ParseError{message: "no rule matches"}}
    end
  end

  def apply_production(:start_element, element, {cxt, graph, bnodes, rdf_ids}) do
    with {:ok, {next_cxt, new_bnodes}} <-
           Rule.apply_production(cxt, element, graph, bnodes) do
      {:ok, {next_cxt, graph, new_bnodes, rdf_ids}}
    end
  end

  def apply_production(:end_element, name, {cxt, graph, bnodes, rdf_ids}) do
    with {:ok, cxt, graph, new_bnodes} <- Rule.end_element(cxt, name, graph, bnodes) do
      {:ok, {cxt, graph, new_bnodes, rdf_ids}}
    end
  end

  def apply_production(:characters, characters, {%rule{} = cxt, graph, bnodes, rdf_ids}) do
    with {:ok, new_cxt} <- rule.characters(characters, cxt) do
      {:ok, {new_cxt, graph, bnodes, rdf_ids}}
    end
  end

  defp check_rdf_id(nil, rdf_ids), do: {:ok, rdf_ids}

  defp check_rdf_id(rdf_id, rdf_ids) do
    if MapSet.member?(rdf_ids, rdf_id) do
      {:error, %RDF.XML.ParseError{message: "multiple uses of ID #{rdf_id}"}}
    else
      {:ok, MapSet.put(rdf_ids, rdf_id)}
    end
  end
end

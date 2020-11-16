defmodule RDF.XML.Decoder.Grammar.LiteralRule do
  @moduledoc false

  use RDF.XML.Decoder.Grammar.Rule, struct: [:name, :attributes]

  def type, do: __MODULE__
  def element_rule?, do: true
  def cascaded_end?, do: false
  def element_cxt(_), do: nil

  def apply(%{} = cxt, name, attributes) do
    {:ok,
     %__MODULE__{
       parent_cxt: cxt,
       name: name,
       attributes: attributes
     }}
  end

  @impl true
  def characters(characters, cxt) do
    {:ok, %{cxt | children: [Saxy.XML.characters(characters) | List.wrap(cxt.children)]}}
  end

  def result_elements(%__MODULE__{name: name, attributes: attributes, children: children}) do
    children =
      if is_list(children) do
        Enum.reverse(children)
      else
        children
      end

    Saxy.XML.element(name, attributes, children)
  end
end

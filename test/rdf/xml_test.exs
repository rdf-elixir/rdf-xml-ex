defmodule RDF.XMLTest do
  use ExUnit.Case
  doctest RDF.XML

  test "greets the world" do
    assert RDF.XML.hello() == :world
  end
end

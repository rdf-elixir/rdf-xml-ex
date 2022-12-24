defmodule RDF.XML.TestData do
  @moduledoc """
  Functions for accessing test data.
  """

  @dir Path.join(File.cwd!(), "test/data/")
  def dir, do: @dir

  def file(name) do
    path = Path.join(@dir, name)

    if File.exists?(path) do
      path
    else
      raise "Test data file '#{name}' not found"
    end
  end
end

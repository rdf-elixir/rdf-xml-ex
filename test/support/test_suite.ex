defmodule RDF.XML.TestSuite do
  defmodule NS do
    use RDF.Vocabulary.Namespace

    defvocab MF,
      base_iri: "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#",
      terms: [],
      strict: false

    defvocab RDFT,
      base_iri: "http://www.w3.org/ns/rdftest#",
      terms: ~w[
        TestXMLEval
        TestXMLNegativeSyntax
      ]
  end

  @compile {:no_warn_undefined, RDF.XML.TestSuite.NS.MF}
  @compile {:no_warn_undefined, RDF.XML.TestSuite.NS.RDFT}

  @base "http://www.w3.org/2013/RDFXMLTests/"
  @dir Path.join(RDF.XML.TestData.dir(), "w3c-rdf-1.1-xml-test-suite")

  alias RDF
  alias NS.MF

  alias RDF.{Turtle, Graph, Description, IRI}

  def file(filename), do: @dir |> Path.join(filename)
  def manifest_path(), do: file("manifest.ttl")

  def manifest_graph(opts \\ []) do
    manifest_path() |> Turtle.read_file!(opts)
  end

  def test_cases(test_type, opts \\ []) do
    Keyword.merge([base: @base], opts)
    |> manifest_graph()
    |> Graph.descriptions()
    |> Enum.filter(fn description ->
      RDF.iri(test_type) in Description.get(description, RDF.type(), [])
    end)
  end

  def test_name(test_case), do: value(test_case, MF.name())
  def test_title(test_case), do: test_name(test_case)
  def test_input_file(test_case), do: test_case |> Description.first(MF.action())
  def test_output_file(test_case), do: test_case |> Description.first(MF.result())

  def test_input_file_path(test_case),
    do: test_case |> test_input_file() |> to_string() |> String.trim_leading(@base) |> file()

  def test_result_file_path(test_case),
    do: test_case |> test_output_file() |> to_string() |> String.trim_leading(@base) |> file()

  defp value(description, property),
    do: Description.first(description, property) |> to_string
end

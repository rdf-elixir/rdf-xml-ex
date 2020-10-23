defmodule RDF.XML.W3C.Test do
  @moduledoc """
  The official W3C RDF 1.1 XML Test Suite.

  from <https://www.w3.org/2013/RDFXMLTests/>
  """

  use ExUnit.Case, async: false
  ExUnit.Case.register_attribute(__ENV__, :test_case)

  alias RDF.NTriples
  alias RDF.XML.TestSuite
  alias TestSuite.NS.RDFT

  TestSuite.test_cases(RDFT.TestXMLEval)
  |> Enum.each(fn test_case ->
    @tag test_case: test_case

    if TestSuite.test_name(test_case) in [
         "rdf-ns-prefix-confusion-test0010",
         "rdf-ns-prefix-confusion-test0011",
         "rdf-ns-prefix-confusion-test0012",
         "rdf-ns-prefix-confusion-test0013",
         "rdf-ns-prefix-confusion-test0014"
       ] do
      @tag skip: "TODO: handle xmlns for syntax terms"
    end

    if TestSuite.test_name(test_case) in [
         "rdfms-not-id-and-resource-attr-test001",
         "rdfms-not-id-and-resource-attr-test004",
         "rdfms-not-id-and-resource-attr-test005",
         "rdfms-empty-property-elements-test005",
         "rdfms-empty-property-elements-test011",
         "rdfms-syntax-incomplete-test004"
       ] do
      @tag skip: "TODO: reification"
    end

    if TestSuite.test_name(test_case) in [
         "rdfms-rdf-names-use-test-031",
         "rdf-containers-syntax-vs-schema-test001",
         "rdfms-identity-anon-resources-test004",
         "rdf-containers-syntax-vs-schema-test002",
         "rdf-containers-syntax-vs-schema-test003",
         "rdf-containers-syntax-vs-schema-test004",
         "rdf-containers-syntax-vs-schema-test006",
         "rdf-containers-syntax-vs-schema-test007",
         "rdf-containers-syntax-vs-schema-test008"
       ] do
      @tag skip: "TODO: lists and containers"
    end

    if TestSuite.test_name(test_case) in [
         "rdf-ns-prefix-confusion-test0005",
         "rdfms-empty-property-elements-test004",
         "rdfms-empty-property-elements-test006",
         "rdfms-empty-property-elements-test010",
         "rdfms-empty-property-elements-test012",
         "rdfms-seq-representation-test001",
         "rdfms-syntax-incomplete-test002"
       ] do
      @tag skip: "TODO: parseType=Resource"
    end

    if TestSuite.test_name(test_case) in [
         "xml-canon-test001"
       ] do
      @tag skip: "TODO: parseType=Literal"
    end

    if TestSuite.test_name(test_case) in [
         "xmlbase-test004",
         "rdf-charmod-literals-test001",
         "rdf-element-not-mandatory-test001",
         "rdfms-uri-substructure-test001",
         "rdfms-not-id-and-resource-attr-test002",
         "rdfms-syntax-incomplete-test003",
         "rdfms-empty-property-elements-test014",
         "rdfms-empty-property-elements-test015"
       ] do
      @tag skip: """
           The produced graphs are correct, but have different blank node labels than the result graph.
           TODO: Implement a graph isomorphism algorithm.
           """
    end

    test TestSuite.test_title(test_case), %{test_case: test_case} do
      base = to_string(TestSuite.test_input_file(test_case))

      assert RDF.Graph.equal?(
               TestSuite.test_input_file_path(test_case)
               |> RDF.XML.read_file!(base: base, bnode_prefix: "j"),
               TestSuite.test_result_file_path(test_case)
               |> NTriples.read_file!()
             )
    end
  end)

  TestSuite.test_cases(RDFT.TestXMLNegativeSyntax)
  |> Enum.each(fn test_case ->
    @tag test_case: test_case
    test TestSuite.test_title(test_case), %{test_case: test_case} do
      base = to_string(TestSuite.test_input_file(test_case))

      assert {:error, _} =
               TestSuite.test_input_file_path(test_case)
               |> RDF.XML.read_file(base: base)
    end
  end)
end

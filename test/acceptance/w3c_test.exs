defmodule RDF.XML.W3C.Test do
  @moduledoc """
  The official W3C RDF 1.1 XML Test Suite.

  from <https://www.w3.org/2013/RDFXMLTests/>
  """

  use ExUnit.Case, async: false
  use RDF.Test.EarlFormatter, test_suite: :rdf_xml

  ExUnit.Case.register_attribute(__ENV__, :test_case)

  alias RDF.NTriples
  alias RDF.XML.TestSuite
  alias TestSuite.NS.RDFT

  TestSuite.test_cases(RDFT.TestXMLEval)
  |> Enum.each(fn test_case ->
    @tag test_case: test_case

    if TestSuite.test_name(test_case) == "rdf-element-not-mandatory-test001" do
      @tag earl_result: :failed
      @tag skip: "TODO: the rdf:RDF element is no longer mandatory"
    end

    if TestSuite.test_name(test_case) == "rdfms-syntax-incomplete-test004" do
      @tag earl_result: :failed
      @tag skip: "TODO: On a property element rdf:nodeID behaves similarly to rdf:resource."
    end

    if TestSuite.test_name(test_case) in [
         "rdf-ns-prefix-confusion-test0010",
         "rdf-ns-prefix-confusion-test0011",
         "rdf-ns-prefix-confusion-test0012",
         "rdf-ns-prefix-confusion-test0013",
         "rdf-ns-prefix-confusion-test0014"
       ] do
      @tag earl_result: :failed
      @tag skip: "TODO: handle xmlns for syntax terms"
    end

    if TestSuite.test_name(test_case) in ["xml-canon-test001"] do
      # Note, that this seems to have passed with Saxy < 1.5 just accidentally due to a bug in Saxy
      @tag earl_result: :failed
      @tag skip: "TODO: XML canonicalization is not support"
    end

    test TestSuite.test_title(test_case), %{test_case: test_case} do
      base = to_string(TestSuite.test_input_file(test_case))

      assert {:ok, result} =
               TestSuite.test_input_file_path(test_case)
               |> RDF.XML.read_file(base: base, bnode_prefix: "j")

      assert RDF.Graph.isomorphic?(
               result,
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

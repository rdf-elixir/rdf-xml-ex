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

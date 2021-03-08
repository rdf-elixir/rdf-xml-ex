defmodule RDF.XML.DecoderTest do
  use ExUnit.Case, async: false

  doctest RDF.XML.Decoder

  alias RDF.XML.Decoder
  alias RDF.{Turtle, Graph}

  import RDF.Sigils

  test "single triple with a literal as objects" do
    example_graph =
      """
      @prefix eric:    <http://www.w3.org/People/EM/contact#> .
      @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

      eric:me contact:fullName "Eric Miller" .
      """
      |> Turtle.read_string!()

    assert Decoder.decode("""
           <?xml version="1.0" encoding="utf-8"?>
           <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me">
               <contact:fullName>Eric Miller</contact:fullName>
             </rdf:Description>
           </rdf:RDF>
           """) == {:ok, example_graph}
  end

  test "multiple triples with a literals as objects" do
    example_graph =
      """
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix eric:    <http://www.w3.org/People/EM/contact#> .
      @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .

      eric:me
        contact:fullName "Eric Miller" ;
        contact:personalTitle "Dr."
      .
      """
      |> Turtle.read_string!()

    assert Decoder.decode("""
           <?xml version="1.0" encoding="utf-8"?>
           <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me">
               <contact:fullName>Eric Miller</contact:fullName>
               <contact:personalTitle>Dr.</contact:personalTitle>
             </rdf:Description>
           </rdf:RDF>
           """) == {:ok, example_graph}
  end

  test "language-tagged literals" do
    example_graph =
      """
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix rdfs:    <http://www.w3.org/2000/01/rdf-schema#> .
      @prefix eric:    <http://www.w3.org/People/EM/contact#> .

      eric:me rdfs:comment "Foo"@en .
      """
      |> Turtle.read_string!()

    assert Decoder.decode("""
           <?xml version="1.0" encoding="utf-8"?>
           <rdf:RDF xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me">
               <rdfs:comment xml:lang="en">Foo</rdfs:comment>
             </rdf:Description>
           </rdf:RDF>
           """) == {:ok, example_graph}
  end

  test "datatyped literals" do
    example_graph =
      """
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix eric:    <http://www.w3.org/People/EM/contact#> .
      @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .

      eric:me contact:age 42 .
      """
      |> Turtle.read_string!()

    assert Decoder.decode("""
           <?xml version="1.0" encoding="utf-8"?>
           <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me">
               <contact:age rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">42</contact:age>
             </rdf:Description>
           </rdf:RDF>
           """) == {:ok, example_graph}
  end

  test "parseType=Literal" do
    assert Decoder.decode("""
           <?xml version="1.0"?>
           <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
            xmlns:ex="http://example.org/stuff/1.0/">
             <rdf:Description rdf:about="http://example.org/item01">
               <ex:prop rdf:parseType="Literal" xmlns:a="http://example.org/a#">
                 <a:Box required="true">
                   <a:widget size="10"/>
                   <a:grommit id="23"/>
                 </a:Box>
               </ex:prop>
             </rdf:Description>
           </rdf:RDF>
           """) ==
             {:ok,
              Graph.new(
                prefixes: [rdf: RDF, ex: "http://example.org/stuff/1.0/"],
                init: {
                  ~I<http://example.org/item01>,
                  ~I<http://example.org/stuff/1.0/prop>,
                  RDF.literal(
                    """

                          <a:Box required="true">
                            <a:widget size="10"></a:widget>
                            <a:grommit id="23"></a:grommit>
                          </a:Box>
                    """ <> "    ",
                    datatype: RDF.XMLLiteral
                  )
                }
              )}
  end

  test "parseType=Other" do
    assert Decoder.decode("""
           <?xml version="1.0"?>
           <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
            xmlns:ex="http://example.org/stuff/1.0/">
             <rdf:Description rdf:about="http://example.org/item01">
               <ex:prop rdf:parseType="Other" xmlns:a="http://example.org/a#">
                 <a:Box required="true">
                   <a:widget size="10"/>
                   <a:grommit id="23"/>
                 </a:Box>
               </ex:prop>
             </rdf:Description>
           </rdf:RDF>
           """) ==
             {:ok, Graph.new(prefixes: [rdf: RDF, ex: "http://example.org/stuff/1.0/"])}
  end

  test "single triple with a resource as object with rdf:resource" do
    example_graph =
      """
      @prefix eric:    <http://www.w3.org/People/EM/contact#> .
      @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

      eric:me contact:mailbox <mailto:e.miller123(at)example> .
      """
      |> Turtle.read_string!()

    assert Decoder.decode("""
           <?xml version="1.0" encoding="utf-8"?>
           <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me">
               <contact:mailbox rdf:resource="mailto:e.miller123(at)example"/>
             </rdf:Description>
           </rdf:RDF>
           """) == {:ok, example_graph}
  end

  test "description with a resource as object with rdf:resource and additional properties" do
    example_graph =
      """
      @prefix eric:    <http://www.w3.org/People/EM/contact#> .
      @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix ex:      <http://example.org/> .

      eric:me contact:mailbox <mailto:e.miller123(at)example> .
      <mailto:e.miller123(at)example>
          a contact:Mailbox ;
          ex:p "foo" .
      """
      |> Turtle.read_string!()

    assert Decoder.decode("""
           <?xml version="1.0" encoding="utf-8"?>
           <rdf:RDF xmlns:ex="http://example.org/" xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me">
               <contact:mailbox rdf:resource="mailto:e.miller123(at)example"
                  rdf:type="http://www.w3.org/2000/10/swap/pim/contact#Mailbox"
                  ex:p="foo"
                />
             </rdf:Description>
           </rdf:RDF>
           """) == {:ok, example_graph}
  end

  test "single triple with a resource as object in a nested node" do
    example_graph =
      """
      @prefix eric:    <http://www.w3.org/People/EM/contact#> .
      @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

      eric:me contact:mailbox <mailto:e.miller123(at)example> .
      """
      |> Turtle.read_string!()

    assert Decoder.decode("""
           <?xml version="1.0" encoding="utf-8"?>
           <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me">
               <contact:mailbox>
                 <rdf:Description rdf:about="mailto:e.miller123(at)example">
                 </rdf:Description>
               </contact:mailbox>
             </rdf:Description>
           </rdf:RDF>
           """) == {:ok, example_graph}
  end

  # Note: This tests reification via the ResourcePropertyElt rule which is not covered in the W3C test suite
  test "single reified triple with a resource as object in a nested node" do
    example_graph =
      """
      @prefix eric:    <http://www.w3.org/People/EM/contact#> .
      @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

      eric:me contact:mailbox <mailto:e.miller123(at)example> .

      <#reify> a rdf:Statement ;
          rdf:subject eric:me ;
          rdf:predicate contact:mailbox ;
          rdf:object <mailto:e.miller123(at)example> .
      """
      |> Turtle.read_string!(base: "http://example.org/")

    assert Decoder.decode(
             """
             <?xml version="1.0" encoding="utf-8"?>
             <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
               <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me">
                 <contact:mailbox rdf:ID="reify">
                   <rdf:Description rdf:about="mailto:e.miller123(at)example">
                   </rdf:Description>
                 </contact:mailbox>
               </rdf:Description>
             </rdf:RDF>
             """,
             base: "http://example.org/#"
           ) == {:ok, example_graph}
  end

  test "short description form" do
    example_graph =
      """
      @prefix eric:    <http://www.w3.org/People/EM/contact#> .
      @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

      eric:me
        a contact:Person ;
        contact:fullName "Eric Miller" .
      """
      |> Turtle.read_string!()

    assert Decoder.decode("""
           <?xml version="1.0" encoding="utf-8"?>
           <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
             <contact:Person rdf:about="http://www.w3.org/People/EM/contact#me" contact:fullName="Eric Miller" />
           </rdf:RDF>
           """) == {:ok, example_graph}
  end

  test "multiple triples in separate rdf:Descriptions with literals and URIs as objects" do
    example_graph =
      """
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix eric:    <http://www.w3.org/People/EM/contact#> .
      @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .

      eric:me
        rdf:type contact:Person ;
        contact:fullName "Eric Miller" ;
        contact:mailbox <mailto:e.miller123(at)example> ;
        contact:personalTitle "Dr."
      .
      """
      |> Turtle.read_string!()

    assert Decoder.decode("""
           <?xml version="1.0" encoding="utf-8"?>
           <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me">
               <contact:fullName>Eric Miller</contact:fullName>
             </rdf:Description>
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me">
               <contact:mailbox rdf:resource="mailto:e.miller123(at)example"/>
             </rdf:Description>
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me">
               <contact:personalTitle>Dr.</contact:personalTitle>
             </rdf:Description>
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me">
               <rdf:type rdf:resource="http://www.w3.org/2000/10/swap/pim/contact#Person"/>
             </rdf:Description>
           </rdf:RDF>
           """) == {:ok, example_graph}
  end

  test "property attributes" do
    example_graph =
      """
      @prefix eric:    <http://www.w3.org/People/EM/contact#> .
      @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

      eric:me contact:fullName "Eric Miller" .
      """
      |> Turtle.read_string!()

    assert Decoder.decode("""
           <?xml version="1.0" encoding="utf-8"?>
           <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me" contact:fullName="Eric Miller">
             </rdf:Description>
           </rdf:RDF>
           """) == {:ok, example_graph}
  end

  test "the xml:base is stored in the base_uri field of the graph" do
    base = "http://www.w3.org/People/EM/contact"

    example_graph =
      """
      @base <#{base}> .
      @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

      <#me> contact:fullName "Eric Miller" .
      """
      |> Turtle.read_string!()

    assert Decoder.decode("""
           <?xml version="1.0" encoding="utf-8"?>
           <rdf:RDF xml:base="#{base}" xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
             <rdf:Description rdf:about="#me" contact:fullName="Eric Miller">
             </rdf:Description>
           </rdf:RDF>
           """) == {:ok, example_graph}
  end

  test "use of relative URIs without a base results in an error" do
    assert {:error, %RDF.XML.ParseError{}} =
             Decoder.decode("""
             <?xml version="1.0" encoding="utf-8"?>
             <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
               <rdf:Description rdf:about="#me" contact:fullName="Eric Miller">
               </rdf:Description>
             </rdf:RDF>
             """)
  end

  @tag skip:
         "TODO: unfortunately Saxy doesn't raise an error but silently ignores the first occurrences"
  test "multiple occurrences of the same attribute in an element lead to an error" do
    assert {:error, _} =
             Decoder.decode("""
             <?xml version="1.0" encoding="utf-8"?>
             <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
               <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me" contact:fullName="Eric Miller" contact:fullName="Foo">
               </rdf:Description>
             </rdf:RDF>
             """)
  end

  test "unresolved branching bug (2021-03-05)" do
    assert {:ok, _} =
             Decoder.decode("""
             <?xml version="1.0" encoding="UTF-8"?>
             <rdf:RDF
                 xmlns:ex="http://exmple.com/#"
                 xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                 <ex:Foo rdf:about="http://exmple.com/#Thing">
                     <ex:foo></ex:foo>
                     <ex:bar></ex:bar>
                     <ex:baz>foo</ex:baz>
                 </ex:Foo>
             </rdf:RDF>
             """)
  end

  test "decode_from_stream/2" do
    example_graph =
      """
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix eric:    <http://www.w3.org/People/EM/contact#> .
      @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .

      eric:me
        contact:fullName "Eric Miller" ;
        contact:personalTitle "Dr."
      .
      """
      |> Turtle.read_string!()

    assert """
           <?xml version="1.0" encoding="utf-8"?>
           <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me">
               <contact:fullName>Eric Miller</contact:fullName>
               <contact:personalTitle>Dr.</contact:personalTitle>
             </rdf:Description>
           </rdf:RDF>
           """
           |> string_to_stream()
           |> Decoder.decode_from_stream() == {:ok, example_graph}
  end

  test "stream_support?/0" do
    assert Decoder.stream_support?()
  end

  defp string_to_stream(string) do
    {:ok, pid} = StringIO.open(string)
    IO.binstream(pid, :line)
  end
end

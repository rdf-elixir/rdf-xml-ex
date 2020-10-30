defmodule RDF.XML.DecoderTest do
  use ExUnit.Case, async: false

  test "single triple with a literal as objects" do
    example_graph =
      """
      @prefix eric:    <http://www.w3.org/People/EM/contact#> .
      @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

      eric:me contact:fullName "Eric Miller" .
      """
      |> RDF.Turtle.read_string!()

    assert RDF.XML.Decoder.decode("""
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
      |> RDF.Turtle.read_string!()

    assert RDF.XML.Decoder.decode("""
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
      |> RDF.Turtle.read_string!()

    assert RDF.XML.Decoder.decode("""
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
      |> RDF.Turtle.read_string!()

    assert RDF.XML.Decoder.decode("""
           <?xml version="1.0" encoding="utf-8"?>
           <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me">
               <contact:age rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">42</contact:age>
             </rdf:Description>
           </rdf:RDF>
           """) == {:ok, example_graph}
  end

  test "single triple with a resource as object with rdf:resource" do
    example_graph =
      """
      @prefix eric:    <http://www.w3.org/People/EM/contact#> .
      @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .
      @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

      eric:me contact:mailbox <mailto:e.miller123(at)example> .
      """
      |> RDF.Turtle.read_string!()

    assert RDF.XML.Decoder.decode("""
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
      |> RDF.Turtle.read_string!()

    assert RDF.XML.Decoder.decode("""
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
      |> RDF.Turtle.read_string!()

    assert RDF.XML.Decoder.decode("""
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
      |> RDF.Turtle.read_string!(base: "http://example.org/")

    assert RDF.XML.Decoder.decode(
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
      |> RDF.Turtle.read_string!()

    assert RDF.XML.Decoder.decode("""
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
      |> RDF.Turtle.read_string!()

    assert RDF.XML.Decoder.decode("""
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
      |> RDF.Turtle.read_string!()

    assert RDF.XML.Decoder.decode("""
           <?xml version="1.0" encoding="utf-8"?>
           <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
             <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me" contact:fullName="Eric Miller">
             </rdf:Description>
           </rdf:RDF>
           """) == {:ok, example_graph}
  end

  @tag skip: "TODO: unfortunately Saxy doesn't raise an error but silently ignores the first occurrences"
  test "multiple occurrences of the same attribute in an element lead to an error" do
    assert {:error, _} =
             RDF.XML.Decoder.decode("""
             <?xml version="1.0" encoding="utf-8"?>
             <rdf:RDF xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" xmlns:eric="http://www.w3.org/People/EM/contact#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
               <rdf:Description rdf:about="http://www.w3.org/People/EM/contact#me" contact:fullName="Eric Miller" contact:fullName="Foo">
               </rdf:Description>
             </rdf:RDF>
             """)
  end
end

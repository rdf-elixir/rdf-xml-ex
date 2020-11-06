defmodule RDF.XML.EncoderTest do
  use ExUnit.Case, async: false

  use RDF.Vocabulary.Namespace
  defvocab EX, base_iri: "http://example.com/", terms: [], strict: false

  doctest RDF.XML.Encoder

  alias RDF.XML.Encoder
  alias RDF.{Graph, IRI, XSD, Turtle}

  import RDF.Sigils

  @example_graph """
                 @prefix eric:    <http://www.w3.org/People/EM/contact#> .
                 @prefix contact: <http://www.w3.org/2000/10/swap/pim/contact#> .
                 @prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                 @prefix rdfs:    <http://www.w3.org/2000/01/rdf-schema#> .

                 eric:me
                   rdf:type contact:Person ;
                   contact:fullName "Eric Miller" ;
                   contact:mailbox <mailto:e.miller123(at)example> ;
                   contact:personalTitle "Dr."
                 .

                 <http://example.com/Foo>
                   rdf:type <http://example.com/Bar>, <http://example.com/Baz> ;
                   rdfs:comment "Comment", "Kommentar"@de
                 .
                 """
                 |> Turtle.read_string!()

  test "full example" do
    assert (result = Encoder.encode!(@example_graph)) ==
             ~S[<?xml version="1.0" encoding="utf-8"?>] <>
               ~S[<rdf:RDF ] <>
               ~S[xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" ] <>
               ~S[xmlns:eric="http://www.w3.org/People/EM/contact#" ] <>
               ~S[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ] <>
               ~S[xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">] <>
               ~S[<rdf:Description rdf:about="http://example.com/Foo">] <>
               ~S[<rdf:type rdf:resource="http://example.com/Bar"/>] <>
               ~S[<rdf:type rdf:resource="http://example.com/Baz"/>] <>
               ~S[<rdfs:comment xml:lang="de">Kommentar</rdfs:comment>] <>
               ~S[<rdfs:comment>Comment</rdfs:comment>] <>
               ~S[</rdf:Description>] <>
               ~S[<contact:Person rdf:about="http://www.w3.org/People/EM/contact#me">] <>
               ~S[<contact:fullName>Eric Miller</contact:fullName>] <>
               ~S[<contact:mailbox rdf:resource="mailto:e.miller123(at)example"/>] <>
               ~S[<contact:personalTitle>Dr.</contact:personalTitle>] <>
               ~S[</contact:Person>] <>
               ~S[</rdf:RDF>]

    assert RDF.XML.Decoder.decode(result) == {:ok, @example_graph}
  end

  test "with custom producer function" do
    producer_fun = fn graph ->
      {first, rest} = Graph.pop(graph, ~I<http://www.w3.org/People/EM/contact#me>)
      Stream.concat([first], Graph.descriptions(rest))
    end

    assert (result = Encoder.encode!(@example_graph, producer: producer_fun)) ==
             ~S[<?xml version="1.0" encoding="utf-8"?>] <>
               ~S[<rdf:RDF ] <>
               ~S[xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" ] <>
               ~S[xmlns:eric="http://www.w3.org/People/EM/contact#" ] <>
               ~S[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ] <>
               ~S[xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">] <>
               ~S[<contact:Person rdf:about="http://www.w3.org/People/EM/contact#me">] <>
               ~S[<contact:fullName>Eric Miller</contact:fullName>] <>
               ~S[<contact:mailbox rdf:resource="mailto:e.miller123(at)example"/>] <>
               ~S[<contact:personalTitle>Dr.</contact:personalTitle>] <>
               ~S[</contact:Person>] <>
               ~S[<rdf:Description rdf:about="http://example.com/Foo">] <>
               ~S[<rdf:type rdf:resource="http://example.com/Bar"/>] <>
               ~S[<rdf:type rdf:resource="http://example.com/Baz"/>] <>
               ~S[<rdfs:comment xml:lang="de">Kommentar</rdfs:comment>] <>
               ~S[<rdfs:comment>Comment</rdfs:comment>] <>
               ~S[</rdf:Description>] <>
               ~S[</rdf:RDF>]

    assert RDF.XML.Decoder.decode(result) == {:ok, @example_graph}

    expected_stream_result =
      ~s[<?xml version="1.0" encoding="utf-8"?>\n] <>
        ~S[<rdf:RDF ] <>
        ~S[xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" ] <>
        ~S[xmlns:eric="http://www.w3.org/People/EM/contact#" ] <>
        ~S[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ] <>
        ~s[xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">\n] <>
        ~S[<contact:Person rdf:about="http://www.w3.org/People/EM/contact#me">] <>
        ~S[<contact:fullName>Eric Miller</contact:fullName>] <>
        ~S[<contact:mailbox rdf:resource="mailto:e.miller123(at)example"/>] <>
        ~S[<contact:personalTitle>Dr.</contact:personalTitle>] <>
        ~s[</contact:Person>\n] <>
        ~S[<rdf:Description rdf:about="http://example.com/Foo">] <>
        ~S[<rdf:type rdf:resource="http://example.com/Bar"/>] <>
        ~S[<rdf:type rdf:resource="http://example.com/Baz"/>] <>
        ~S[<rdfs:comment xml:lang="de">Kommentar</rdfs:comment>] <>
        ~S[<rdfs:comment>Comment</rdfs:comment>] <>
        ~s[</rdf:Description>\n] <>
        ~S[</rdf:RDF>]

    assert Encoder.stream(@example_graph, producer: producer_fun, mode: :string)
           |> Enum.to_list()
           |> IO.iodata_to_binary() ==
             expected_stream_result

    assert Encoder.stream(@example_graph, producer: producer_fun, mode: :iodata)
           |> Enum.to_list()
           |> IO.iodata_to_binary() ==
             expected_stream_result
  end

  test "resource URI" do
    assert Graph.new({EX.S, EX.p(), EX.O}, prefixes: [ex: EX])
           |> Encoder.encode!() ==
             xml_description(~s[<ex:p rdf:resource="#{IRI.to_string(EX.O)}"/>])
  end

  test "resource URI against base" do
    assert Graph.new({EX.S, EX.p(), EX.O}, prefixes: [ex: EX])
           |> Encoder.encode!(base_iri: EX) ==
             xml_description_with_base(~S[<ex:p rdf:resource="O"/>])

    assert Graph.new({EX.S, EX.p(), EX.O}, prefixes: [ex: EX], base_iri: EX)
           |> Encoder.encode!() ==
             xml_description_with_base(~S[<ex:p rdf:resource="O"/>])
  end

  test "resource URI against base with use_rdf_id: true" do
    assert Graph.new({EX.__base_iri__() <> "#S", EX.p(), RDF.iri(EX.__base_iri__() <> "#O")},
             prefixes: [ex: EX],
             base_iri: EX
           )
           |> Encoder.encode!(use_rdf_id: true) ==
             xml_description_with_base(~S[<ex:p rdf:resource="#O"/>],
               subject: ~S[rdf:ID="S"]
             )
  end

  test "when base URI contains fragments (which are essentially ignored)" do
    assert Graph.new({EX.S, EX.p(), EX.O},
             prefixes: [ex: EX],
             base_iri: EX.__base_iri__() <> "#foo"
           )
           |> Encoder.encode!() ==
             xml_description_with_base(~S[<ex:p rdf:resource="O"/>])

    assert Graph.new({EX.__base_iri__() <> "#S", EX.p(), RDF.iri(EX.__base_iri__() <> "#O")},
             prefixes: [ex: EX],
             base_iri: EX.__base_iri__() <> "#foo"
           )
           |> Encoder.encode!(use_rdf_id: true) ==
             xml_description_with_base(~S[<ex:p rdf:resource="#O"/>],
               subject: ~S[rdf:ID="S"]
             )
  end

  test "string literal" do
    assert Graph.new({EX.S, EX.p(), ~L"Foo"}, prefixes: [ex: EX])
           |> Encoder.encode!() ==
             xml_description("<ex:p>Foo</ex:p>")
  end

  test "language-tagged literal" do
    assert Graph.new({EX.S, EX.p(), ~L"Foo"de}, prefixes: [ex: EX])
           |> Encoder.encode!() ==
             xml_description(~S[<ex:p xml:lang="de">Foo</ex:p>])
  end

  test "typed literal" do
    assert Graph.new({EX.S, EX.p(), XSD.integer(42)}, prefixes: [ex: EX])
           |> Encoder.encode!() ==
             xml_description(
               ~S[<ex:p rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">42</ex:p>]
             )
  end

  test "empty xmlns" do
    assert Graph.new([{EX.S, EX.p(), EX.O}, {EX.S, RDF.type(), EX.Class}], prefixes: [nil: EX])
           |> Encoder.encode!() ==
             ~S[<?xml version="1.0" encoding="utf-8"?>] <>
               ~s[<rdf:RDF xmlns="#{EX.__base_iri__()}">] <>
               ~s[<Class rdf:about="#{IRI.to_string(EX.S)}">] <>
               ~s[<p rdf:resource="#{IRI.to_string(EX.O)}"/>] <>
               ~S[</Class>] <>
               ~S[</rdf:RDF>]
  end

  describe "stream/2" do
    expected_result =
      ~s[<?xml version="1.0" encoding="utf-8"?>\n] <>
        ~S[<rdf:RDF ] <>
        ~S[xmlns:contact="http://www.w3.org/2000/10/swap/pim/contact#" ] <>
        ~S[xmlns:eric="http://www.w3.org/People/EM/contact#" ] <>
        ~S[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ] <>
        ~s[xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">\n] <>
        ~S[<rdf:Description rdf:about="http://example.com/Foo">] <>
        ~S[<rdf:type rdf:resource="http://example.com/Bar"/>] <>
        ~S[<rdf:type rdf:resource="http://example.com/Baz"/>] <>
        ~S[<rdfs:comment xml:lang="de">Kommentar</rdfs:comment>] <>
        ~S[<rdfs:comment>Comment</rdfs:comment>] <>
        ~s[</rdf:Description>\n] <>
        ~S[<contact:Person rdf:about="http://www.w3.org/People/EM/contact#me">] <>
        ~S[<contact:fullName>Eric Miller</contact:fullName>] <>
        ~S[<contact:mailbox rdf:resource="mailto:e.miller123(at)example"/>] <>
        ~S[<contact:personalTitle>Dr.</contact:personalTitle>] <>
        ~s[</contact:Person>\n] <>
        ~S[</rdf:RDF>]

    assert Encoder.stream(@example_graph, mode: :string)
           |> Enum.to_list()
           |> IO.iodata_to_binary() ==
             expected_result

    assert Encoder.stream(@example_graph, mode: :iodata)
           |> Enum.to_list()
           |> IO.iodata_to_binary() ==
             expected_result
  end

  test "stream_support?/0" do
    assert Encoder.stream_support?()
  end

  def xml_description(triples) do
    ~S[<?xml version="1.0" encoding="utf-8"?>] <>
      ~S[<rdf:RDF xmlns:ex="http://example.com/">] <>
      ~S[<rdf:Description rdf:about="http://example.com/S">] <>
      triples <>
      ~S[</rdf:Description>] <>
      ~S[</rdf:RDF>]
  end

  def xml_description_with_base(triples, opts \\ []) do
    base = Keyword.get(opts, :base, EX.__base_iri__())
    subject = Keyword.get(opts, :subject, ~S[rdf:about="S"])

    ~S[<?xml version="1.0" encoding="utf-8"?>] <>
      ~s[<rdf:RDF xml:base="#{base}" xmlns:ex="http://example.com/">] <>
      ~s[<rdf:Description #{subject}>] <>
      triples <>
      ~S[</rdf:Description>] <>
      ~S[</rdf:RDF>]
  end
end

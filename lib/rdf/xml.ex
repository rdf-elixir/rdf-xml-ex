defmodule RDF.XML do
  @moduledoc """
  An implementation of the RDF 1.1 XML Syntax.

  It is implemented as a `RDF.Serialization.Format`, so it can be used like any other
  serialization format of RDF.ex.

      graph = RDF.XML.read_file!("file.rdf")
      RDF.XML.write_file!(graph, "file.rdf")

  For a description of the capabilities and options (which can be passed also to
  the `read` and `write` functions) see `RDF.XML.Decoder` and `RDF.XML.Encoder` respectively.

  See also <http://www.w3.org/TR/rdf-syntax-grammar/>.
  """

  use RDF.Serialization.Format

  import RDF.Sigils

  @id ~I<http://www.w3.org/ns/formats/RDF_XML>
  @name :rdf_xml
  @extension "rdf"
  @media_type "application/rdf+xml"
end

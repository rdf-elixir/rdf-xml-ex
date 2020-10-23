defmodule RDF.XML do
  @moduledoc """
  An implementation of the RDF 1.1 XML Syntax.

  It is implemented as a `RDF.Serialization.Format`, so it can be used like any other
  serialization format of RDF.ex.

  see <http://www.w3.org/TR/rdf-syntax-grammar/>
  """

  use RDF.Serialization.Format

  import RDF.Sigils

  @id ~I<http://www.w3.org/ns/formats/RDF_XML>
  @name :rdf_xml
  @extension "rdf"
  @media_type "application/rdf+xml"
end

<img src="rdf-xml-logo-96.png" align="right" />

# RDF-XML.ex

[![Hex.pm](https://img.shields.io/hexpm/v/rdf_xml.svg?style=flat-square)](https://hex.pm/packages/rdf_xml)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/rdf_xml/)
[![License](https://img.shields.io/hexpm/l/rdf_xml.svg)](https://github.com/rdf-elixir/rdf-xml-ex/blob/master/LICENSE.md)

[![ExUnit Tests](https://github.com/rdf-elixir/rdf-xml-ex/actions/workflows/elixir-build-and-test.yml/badge.svg)](https://github.com/rdf-elixir/rdf-xml-ex/actions/workflows/elixir-build-and-test.yml)
[![Dialyzer](https://github.com/rdf-elixir/rdf-xml-ex/actions/workflows/elixir-dialyzer.yml/badge.svg)](https://github.com/rdf-elixir/rdf-xml-ex/actions/workflows/elixir-dialyzer.yml)
[![Quality Checks](https://github.com/rdf-elixir/rdf-xml-ex/actions/workflows/elixir-quality-checks.yml/badge.svg)](https://github.com/rdf-elixir/rdf-xml-ex/actions/workflows/elixir-quality-checks.yml)


An implementation of the [W3C RDF 1.1 XML](http://www.w3.org/TR/rdf-syntax-grammar/) serialization format for Elixir and [RDF.ex].

The API documentation can be found [here](https://hexdocs.pm/rdf_xml/). For a guide and more information about RDF.ex and it's related projects, go to <https://rdf-elixir.dev>.


## Features

- fully conforming RDF/XML implementation passing all the official tests (apart from the currently unsupported features below)
- reader/writer for [RDF.ex] with support for reading and writing to streams



## Limitations

- XML canonicalization of `rdf:XMLLiteral`s  (`rdf:parseType="Literal"`) is not supported
- xmlns for `rdf` to shorten the syntax terms is not supported



## Installation

The [RDF-XML.ex](https://hex.pm/packages/rdf_xml) Hex package can be installed as usual, by adding `rdf_xml` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:rdf_xml, "~> 1.1"}]
end
```


## Usage

RDF-XML.ex can be used to serialize or deserialize RDF data structures by using the RDF.ex reader and writer functions as usual.

```elixir
graph = RDF.XML.read_file!("file.rdf")
RDF.XML.write_file!(graph, "file.rdf")
```

Above the common options of all RDF.ex encoders and decoders, the encoder and decoder of RDF-XML.ex supports some additional options. See the [API documentation](https://hexdocs.pm/rdf_xml/) for information about the available options.



## Contributing

see [CONTRIBUTING](CONTRIBUTING.md) for details.



## Acknowledgements

The development of this project was sponsored by [NetzeBW](https://www.netze-bw.de/) for [NETZlive](https://www.netze-bw.de/unsernetz/netzinnovationen/digitalisierung/netzlive).



## Consulting

If you need help with your Elixir and Linked Data projects, just contact [NinjaConcept](https://www.ninjaconcept.com/) via <contact@ninjaconcept.com>.



## License and Copyright

(c) 2020-present Marcel Otto. MIT Licensed, see [LICENSE](LICENSE.md) for details.



[RDF.ex]:             https://hex.pm/packages/rdf


<img src="rdf-xml-logo-96.png" align="right" />

# RDF-XML.ex

An implementation of the [W3C RDF 1.1 XML](http://www.w3.org/TR/rdf-syntax-grammar/) serialization format for Elixir and [RDF.ex].

The API documentation can be found [here](https://hexdocs.pm/rdf_xml/). For a guide and more information about RDF.ex and it's related projects, go to <https://rdf-elixir.dev>.


## Features

- fully conforming RDF/XML implementation passing all of the official tests (apart from the currently unsupported features below)
- reader/writer for [RDF.ex] with support for reading and writing to streams



## TODO

- `parseType="Literal"` and `parseType="Other"` 
- xmlns for `rdf` to shorten the syntax terms



## Installation

The [RDF-XML.ex](https://hex.pm/packages/rdf_xml) Hex package can be installed as usual, by adding `rdf_xml` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:rdf_xml, "~> 0.1"}]
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


## License and Copyright

(c) 2020 Marcel Otto. MIT Licensed, see [LICENSE](LICENSE.md) for details.



[RDF.ex]:             https://hex.pm/packages/rdf


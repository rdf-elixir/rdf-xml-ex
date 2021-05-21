# Change Log

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/) and
[Keep a CHANGELOG](http://keepachangelog.com).


## v0.1.4 - 2021-05-21

### Fixed

- encoding of typed literals failed when a base URI was present


[Compare v0.1.3...v0.1.4](https://github.com/rdf-elixir/rdf-xml-ex/compare/v0.1.3...v0.1.4)



## v0.1.3 - 2021-03-12

### Added

- the `:use_rdf_id` option of the encoder now accepts a function which allows determining
  for every `RDF.Description` individually if it should be encoded with `rdf:ID`  

### Fixed

- a bug in the decoder introduced by the changes in the last version causing production
  of erroneous empty strings as objects when property attributes on a nested blank nodes 
  are used


[Compare v0.1.2...v0.1.3](https://github.com/rdf-elixir/rdf-xml-ex/compare/v0.1.2...v0.1.3)



## v0.1.2 - 2021-03-09

### Fixed

- a bug which prevented some valid RDF/XML serializations from successful decoding 


[Compare v0.1.1...v0.1.2](https://github.com/rdf-elixir/rdf-xml-ex/compare/v0.1.1...v0.1.2)



## v0.1.1 - 2021-02-12

### Changed

- the `xml:base` specified on the `rdf:RDF` element is stored in the `base_uri`
  field of the decoded `RDF.Graph` 

### Fixed

- when encoding to a stream in string mode not all elements where strings 
  (some were still iolists) 


[Compare v0.1.0...v0.1.1](https://github.com/rdf-elixir/rdf-xml-ex/compare/v0.1.0...v0.1.1)



## v0.1.0 - 2020-11-16

Initial release

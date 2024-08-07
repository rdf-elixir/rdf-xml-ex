# Change Log

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/) and
[Keep a CHANGELOG](http://keepachangelog.com).


## v1.2.0 - 2024-08-07

This version upgrades to RDF.ex v2.0.

Elixir versions < 1.13 and OTP version < 23 are no longer supported.


[Compare v1.1.1...v1.2.0](https://github.com/rdf-elixir/rdf-xml-ex/compare/v1.1.1...v1.2.0)



## v1.1.1 - 2024-03-18

### Added 

- optimizations of relative URI resolution against the base URI 
  (in non-`rdf:ID` cases)  


[Compare v1.1.0...v1.1.1](https://github.com/rdf-elixir/rdf-xml-ex/compare/v1.1.0...v1.1.1)



## v1.1.0 - 2024-01-16

Elixir versions < 1.12 are no longer supported

### Added

- option `:xml_declaration` on `RDF.XML.encode/2` and `RDF.XML.stream/2` to
  customize or omit the generation of the XML declaration

### Fixed

- inconsistent encodings with OTP 26 by generally enforcing alphanumeric 
  ordering of namespace declarations during encoding


[Compare v1.0.0...v1.1.0](https://github.com/rdf-elixir/rdf-xml-ex/compare/v1.0.0...v1.1.0)



## v1.0.0 - 2022-11-03

This version is just upgraded to RDF.ex v1.0.

Elixir versions < 1.11 are no longer supported

[Compare v0.1.5...v1.0.0](https://github.com/rdf-elixir/rdf-xml-ex/compare/v0.1.5...v1.0.0)



## v0.1.5 - 2021-12-23

This version just fixes the RDF.ex dependency specification to support RDF.ex v0.10.

Elixir versions < 1.10 are no longer supported


[Compare v0.1.4...v0.1.5](https://github.com/rdf-elixir/rdf-xml-ex/compare/v0.1.4...v0.1.5)



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

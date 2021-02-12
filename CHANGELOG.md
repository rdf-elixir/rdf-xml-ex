# Change Log

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/) and
[Keep a CHANGELOG](http://keepachangelog.com).


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

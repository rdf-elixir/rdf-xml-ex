import Config

if Mix.env() == :test do
  config :rdf_xml, :earl_formatter, author_iri: "http://marcelotto.net/#me"
end

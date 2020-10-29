alias RDF.XML.Decoder

data_dir = "bench/data/"
example_file = Path.join(data_dir, "org.rdf")
example_xml = File.read!(example_file)

Benchee.run(
  %{
    "example from string" => fn -> {:ok, _} = Decoder.decode(example_xml) end
  },
  memory_time: 2
)

alias RDF.XML.Encoder

data_dir = "bench/data/"
example_file = Path.join(data_dir, "org.rdf")
example_xml = File.read!(example_file)
example_graph = RDF.XML.Decoder.decode!(example_xml)

Benchee.run(
  %{
    "encode to string directly" => fn ->
      {:ok, xml} = Encoder.encode(example_graph)
    end,
    "encode to string via string stream" => fn ->
      example_graph
      |> Encoder.stream(mode: :string)
      |> Enum.to_list()
      |> IO.iodata_to_binary()
    end,
    "encode to string via iodata stream" => fn ->
      example_graph
      |> Encoder.stream(mode: :iodata)
      |> Enum.to_list()
      |> IO.iodata_to_binary()
    end
  },
  memory_time: 2
)

tmp_dir = System.tmp_dir!()
tmp_file = Path.join(tmp_dir, "rdf_xml_encode_bench.rdf")

Benchee.run(
  %{
    "encode to file directly" => fn ->
      {:ok, xml} = Encoder.encode(example_graph)
      File.write!(tmp_file, xml)
    end,
    "encode to file via string stream" => fn ->
      example_graph
      |> Encoder.stream(mode: :string)
      |> Enum.into(File.stream!(tmp_file))
    end,
    "encode to file via iodata stream" => fn ->
      example_graph
      |> Encoder.stream(mode: :iodata)
      |> Enum.into(File.stream!(tmp_file))
    end
  },
  memory_time: 2
)

if File.exists?(tmp_file) do
  File.rm!(tmp_file)
end

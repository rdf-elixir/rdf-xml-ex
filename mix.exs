defmodule RDF.XML.MixProject do
  use Mix.Project

  @repo_url "https://github.com/rdf-elixir/rdf-xml-ex"

  @version File.read!("VERSION") |> String.trim()

  def project do
    [
      app: :rdf_xml,
      version: @version,
      elixir: "~> 1.9",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex
      package: package(),
      description: description(),

      # Docs
      name: "RDF-XML.ex",
      docs: [
        main: "RDF.XML",
        source_url: @repo_url,
        source_ref: "v#{@version}",
        extras: ["README.md", "CHANGELOG.md"]
      ],

      # Dialyzer
      dialyzer: dialyzer(),

      # ExCoveralls
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp description do
    """
    An implementation of RDF-XML for Elixir and RDF.ex.
    """
  end

  defp package do
    [
      maintainers: ["Marcel Otto"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url},
      files: ~w[lib mix.exs README.md LICENSE.md VERSION]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:rdf, "~> 0.9.1"},
      {:saxy, "~> 1.2"},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:excoveralls, "~> 0.14", only: :test},
      {:benchee, "~> 1.0", only: :dev}
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end

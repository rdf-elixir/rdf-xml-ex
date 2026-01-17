defmodule RDF.XML.MixProject do
  use Mix.Project

  @repo_url "https://github.com/rdf-elixir/rdf-xml-ex"

  @version File.read!("VERSION") |> String.trim()

  def project do
    [
      app: :rdf_xml,
      version: @version,
      elixir: "~> 1.14",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
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
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: [
        check: :test,
        earl_reports: :test,
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
      rdf_ex_dep(:rdf, "~> 2.0"),
      {:saxy, "~> 1.2"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      # This dependency is needed for ExCoveralls when OTP < 25
      {:castore, "~> 1.0", only: :test},
      {:benchee, "~> 1.1", only: :dev}
    ]
  end

  defp rdf_ex_dep(dep, version) do
    case System.get_env("RDF_EX_PACKAGES_SRC") do
      "LOCAL" -> {dep, path: "../#{dep}"}
      _ -> {dep, version}
    end
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  defp aliases do
    [
      earl_reports: &earl_reports/1,
      check: [
        "clean",
        "deps.unlock --check-unused",
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test --warnings-as-errors",
        "credo"
      ]
    ]
  end

  defp earl_reports(_) do
    files = ["test/acceptance/w3c_test.exs"]

    Mix.Task.run("test", ["--formatter", "RDF.Test.EarlFormatter", "--seed", "0"] ++ files)
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end

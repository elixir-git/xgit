defmodule Xgit.MixProject do
  use Mix.Project

  @version "0.2.3"

  def project do
    [
      app: :xgit,
      version: @version,
      name: "Xgit",
      elixir: "~> 1.8",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      build_per_environment: false,
      test_coverage: [tool: ExCoveralls],
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application, do: [mod: {Xgit, []}, extra_applications: [:logger]]

  defp deps do
    [
      {:benchee, "~> 1.0", only: :dev},
      {:con_cache, "~> 0.13"},
      {:credo, "~> 1.1", only: [:dev, :test]},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:excoveralls, "~> 0.11", only: :test},
      {:ex_doc, "~> 0.21", only: :dev},
      {:temp, "~> 0.4", only: [:dev, :test]}
    ]
  end

  defp description, do: "Pure Elixir native implementation of git"

  defp package do
    [
      maintainers: ["Eric Scouten"],
      licenses: ["Apache2"],
      links: %{"Github" => "https://github.com/elixir-git/xgit", "Reflog" => "https://xgit.io"}
    ]
  end

  defp docs do
    [
      main: "Xgit",
      source_ref: "v#{@version}",
      logo: "branding/xgit-logo.png",
      canonical: "http://hexdocs.pm/xgit",
      source_url: "https://github.com/elixir-git/xgit",
      homepage_url: "https://xgit.io"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end

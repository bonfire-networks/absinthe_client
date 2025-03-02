defmodule AbsintheClient.Mixfile do
  use Mix.Project

  @version "2.0.0"

  def project do
    [
      app: :absinthe_client,
      version: @version,
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      docs: [source_ref: "v#{@version}"],
      package: package(),
      deps: deps()
    ]
  end

  defp package do
    [
      description:
        "Subscription support via Phoenix for Absinthe, the GraphQL implementation for Elixir.",
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Ben Wilson", "Bruce Williams"],
      licenses: ["MIT"],
      links: %{
        Website: "https://absinthe-graphql.org",
        Changelog:
          "https://github.com/absinthe-graphql/absinthe_client/blob/master/CHANGELOG.md",
        GitHub: "https://github.com/absinthe-graphql/absinthe_client"
      }
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:absinthe_plug, "~> 1.5.0"},
      {:absinthe, "~> 1.7.0"},
      {:decimal, "~> 1.6 or ~> 2.0"},
      {:phoenix, "~> 1.7.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_html, "~> 4.1", optional: true},
      {:ex_doc, "~> 0.14", only: :dev},
      {:jason, "~> 1.0", only: [:dev, :test]},
      {:phoenix_live_view, "~> 0.20", optional: true}
    ]
  end
end

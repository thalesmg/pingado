defmodule Pingado.MixProject do
  use Mix.Project

  def project do
    [
      app: :pingado,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: false,
      aliases: [
        fmt: ["format"]
      ],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:snabbkaffe, "~> 1.0"}
    ]
  end
end

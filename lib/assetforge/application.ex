defmodule Assetforge.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AssetforgeWeb.Telemetry,
      Assetforge.Repo,
      {DNSCluster, query: Application.get_env(:assetforge, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Assetforge.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Assetforge.Finch},
      # Start a worker by calling: Assetforge.Worker.start_link(arg)
      # {Assetforge.Worker, arg},
      # Start to serve requests, typically the last entry
      AssetforgeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Assetforge.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AssetforgeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

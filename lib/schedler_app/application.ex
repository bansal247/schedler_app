defmodule SchedlerApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SchedlerAppWeb.Telemetry,
      SchedlerApp.Repo,
      {DNSCluster, query: Application.get_env(:schedler_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SchedlerApp.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: SchedlerApp.Finch},
      # Start a worker by calling: SchedlerApp.Worker.start_link(arg)
      # {SchedlerApp.Worker, arg},
      # Start to serve requests, typically the last entry
      SchedlerAppWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SchedlerApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SchedlerAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

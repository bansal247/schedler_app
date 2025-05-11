defmodule SchedlerApp.Repo do
  use Ecto.Repo,
    otp_app: :schedler_app,
    adapter: Ecto.Adapters.Postgres
end

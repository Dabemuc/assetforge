defmodule Assetforge.Repo do
  use Ecto.Repo,
    otp_app: :assetforge,
    adapter: Ecto.Adapters.Postgres
end

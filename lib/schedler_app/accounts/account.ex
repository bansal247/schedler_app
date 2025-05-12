defmodule SchedlerApp.Accounts.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :email, :string
    field :name, :string
    field :uid, :string
    field :provider, :string
    field :token, :string
    field :refresh_token, :string
    field :token_expires_at, :utc_datetime

    belongs_to :user, SchedlerApp.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :email,
      :name,
      :provider,
      :uid,
      :token,
      :refresh_token,
      :token_expires_at,
      :user_id
    ])
    |> validate_required([:email, :provider, :token, :user_id, :refresh_token])
  end
end

defmodule SchedlerApp.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :name, :string
      add :uid, :string
      add :google_token, :string, null: false
      add :google_refresh_token, :string
      add :google_token_expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:uid])
  end
end

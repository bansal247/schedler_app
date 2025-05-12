defmodule SchedlerApp.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :email, :string, null: false
      add :name, :string
      add :uid, :string
      add :provider, :string, null: false
      add :token, :string, null: false
      add :refresh_token, :string
      add :token_expires_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:accounts, [:user_id])
    create unique_index(:accounts, [:uid])
  end
end

defmodule SchedlerApp.Repo.Migrations.CreateWindows do
  use Ecto.Migration

  def change do
    create table(:windows) do
      add :start_hour, :utc_datetime, null: false
      add :end_hour, :utc_datetime, null: false
      add :weekday, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end
  end
end

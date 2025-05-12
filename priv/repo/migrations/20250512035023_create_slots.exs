defmodule SchedlerApp.Repo.Migrations.CreateSlots do
  use Ecto.Migration

  def change do
    create table(:slots) do
      add :utc_datetime, :utc_datetime, null: false
      add :is_booked, :boolean, default: false, null: false
      add :scheduling_link_id, references(:scheduling_links, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:slots, [:scheduling_link_id])
  end
end

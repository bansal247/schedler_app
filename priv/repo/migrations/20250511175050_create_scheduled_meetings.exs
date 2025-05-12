defmodule SchedlerApp.Repo.Migrations.CreateScheduledMeetings do
  use Ecto.Migration

  def change do
    create table(:scheduled_meetings) do
      add :email, :string, null: false
      add :linkedin, :string
      add :scheduled_at, :utc_datetime, null: false
      add :answers, {:array, :string}
      add :augmented_answer, :string
      add :scheduling_link_id, references(:scheduling_links, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:scheduled_meetings, [:scheduling_link_id])
    create index(:scheduled_meetings, [:user_id])
  end
end

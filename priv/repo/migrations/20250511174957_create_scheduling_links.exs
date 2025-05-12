defmodule SchedlerApp.Repo.Migrations.CreateSchedulingLinks do
  use Ecto.Migration

  def change do
    create table(:scheduling_links) do
      add :window_id, references(:windows, on_delete: :delete_all), null: false
      add :max_uses, :integer
      add :expires_at, :date
      add :questions, :string
      add :meeting_length, :integer, null: false
      add :max_days_ahead, :integer, null: false
      add :token, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:scheduling_links, [:token])
    create index(:scheduling_links, [:window_id])
    create index(:scheduling_links, [:user_id])
  end
end

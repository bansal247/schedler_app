# filepath: /home/shashu/schedler_app/priv/repo/migrations/YYYYMMDDHHMMSS_change_augmented_answer_to_text.exs
defmodule SchedlerApp.Repo.Migrations.ChangeAugmentedAnswerToText do
  use Ecto.Migration

  def up do
    alter table(:scheduled_meetings) do
      modify :augmented_answer, :text
    end
  end

  def down do
    alter table(:scheduled_meetings) do
      modify :augmented_answer, :string
    end
  end
end

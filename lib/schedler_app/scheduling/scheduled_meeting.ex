defmodule SchedlerApp.Scheduling.ScheduledMeeting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scheduled_meetings" do
    field :email, :string
    field :linkedin, :string
    field :scheduled_at, :utc_datetime
    field :answers, {:array, :string}
    field :augmented_answer, :string, default: nil

    belongs_to :scheduling_link, SchedlerApp.Scheduling.SchedulingLink
    belongs_to :user, SchedlerApp.Accounts.User

    timestamps()
  end

  def changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [
      :email,
      :augmented_answer,
      :linkedin,
      :scheduled_at,
      :answers,
      :scheduling_link_id,
      :user_id
    ])
    |> validate_required([:email, :scheduled_at, :scheduling_link_id, :user_id])
  end
end

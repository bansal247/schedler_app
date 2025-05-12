defmodule SchedlerApp.Scheduling.SchedulingLink do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scheduling_links" do
    field :max_uses, :integer
    field :expires_at, :date
    field :questions, :string
    field :meeting_length, :integer
    field :max_days_ahead, :integer
    field :token, :string

    belongs_to :window, SchedlerApp.Scheduling.Window, foreign_key: :window_id
    has_many :scheduled_meetings, SchedlerApp.Scheduling.ScheduledMeeting
    belongs_to :user, SchedlerApp.Accounts.User
    timestamps()
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, [
      :window_id,
      :max_uses,
      :expires_at,
      :questions,
      :meeting_length,
      :max_days_ahead,
      :user_id
    ])
    |> validate_required([:window_id, :meeting_length, :max_days_ahead, :user_id])
    |> put_token()
    |> unique_constraint(:token)
  end

  defp put_token(changeset) do
    if get_field(changeset, :token) do
      changeset
    else
      put_change(changeset, :token, Nanoid.generate())
    end
  end
end

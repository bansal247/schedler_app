defmodule SchedlerApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :name, :string
    field :uid, :string
    field :google_token, :string
    field :google_refresh_token, :string
    field :google_token_expires_at, :utc_datetime
    has_many :accounts, SchedlerApp.Accounts.Account
    has_many :windows, SchedlerApp.Scheduling.Window
    has_many :scheduling_links, SchedlerApp.Scheduling.SchedulingLink
    has_many :scheduled_meetings, SchedlerApp.Scheduling.ScheduledMeeting
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :name,
      :uid,
      :google_token,
      :google_refresh_token,
      :google_token_expires_at
    ])
    |> validate_required([
      :email,
      :google_token
    ])
  end
end

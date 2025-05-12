defmodule SchedlerApp.Scheduling.Window do
  use Ecto.Schema
  import Ecto.Changeset

  alias SchedlerApp.Scheduling.SchedulingLink

  schema "windows" do
    field :start_hour, :utc_datetime
    field :end_hour, :utc_datetime
    field :weekday, :string

    has_one :scheduling_link, SchedulingLink, on_delete: :delete_all
    belongs_to :user, SchedlerApp.Accounts.User
    timestamps(type: :utc_datetime)
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  @doc false
  def changeset(window, attrs) do
    window
    |> cast(attrs, [:start_hour, :end_hour, :weekday, :user_id])
    |> validate_required([:start_hour, :end_hour, :weekday, :user_id])
  end
end

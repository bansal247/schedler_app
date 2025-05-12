defmodule SchedlerApp.Scheduling.Slot do
  use Ecto.Schema
  import Ecto.Changeset

  schema "slots" do
    field :utc_datetime, :utc_datetime
    field :is_booked, :boolean, default: false
    belongs_to :scheduling_link, SchedlerApp.Scheduling.SchedulingLink

    timestamps()
  end

  def changeset(slot, attrs) do
    slot
    |> cast(attrs, [:utc_datetime, :is_booked, :scheduling_link_id])
    |> validate_required([:utc_datetime, :is_booked, :scheduling_link_id])
  end
end

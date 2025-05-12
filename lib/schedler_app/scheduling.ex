defmodule SchedlerApp.Scheduling do
  import Ecto.Query, warn: false
  # import Ecto.Changeset
  alias SchedlerApp.Repo

  alias SchedlerApp.Scheduling.{Window, SchedulingLink, ScheduledMeeting, Slot}

  def list_windows_with_links(user_id) do
    from(w in Window,
      where: w.user_id == ^user_id,
      preload: [:scheduling_link]
    )
    |> Repo.all()
  end

  def get_window!(id) do
    Repo.get!(Window, id)
  end

  def list_scheduled_meetings(user_id) do
    from(sm in ScheduledMeeting,
      where: sm.user_id == ^user_id,
      preload: [:scheduling_link]
    )
    |> Repo.all()
  end

  def create_window(attrs) do
    %Window{}
    |> Window.changeset(attrs)
    |> Repo.insert()
  end

  def get_window(id) do
    Repo.get(Window, id)
  end

  def delete_window(%Window{} = window) do
    Repo.delete(window)
  end

  def create_scheduling_link(attrs) do
    %SchedulingLink{}
    |> SchedulingLink.changeset(attrs)
    |> Repo.insert()
  end

  def create_slot(attrs \\ %{}) do
    %Slot{}
    |> Slot.changeset(attrs)
    |> Repo.insert()
  end

  def get_scheduling_link(id) do
    Repo.get(SchedulingLink, id)
  end

  def get_slots_by_link_id(link_id) do
    from(s in Slot,
      where: s.scheduling_link_id == ^link_id,
      order_by: [asc: s.utc_datetime]
    )
    |> Repo.all()
  end

  def set_slot_booked(slot_id) do
    slot = Repo.get!(Slot, slot_id)

    changeset =
      Slot.changeset(slot, %{is_booked: true})
      |> Ecto.Changeset.put_change(
        :utc_datetime,
        DateTime.utc_now() |> DateTime.truncate(:second)
      )

    Repo.update(changeset)
  end

  def create_scheduled_meeting(attrs) do
    %ScheduledMeeting{}
    |> ScheduledMeeting.changeset(attrs)
    |> Repo.insert()
  end
end

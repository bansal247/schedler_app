defmodule SchedlerAppWeb.DashboardLive do
  use Phoenix.LiveView
  alias SchedlerApp.Accounts
  alias SchedlerAppWeb.Router.Helpers, as: Routes
  alias SchedlerApp.Scheduling
  alias SchedlerApp.Scheduling.Window

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex">
      <!-- Sidebar -->
      <div class="w-1/4 p-4 border-r">
        <h2 class="text-lg font-bold mb-4">Your Accounts</h2>
        <ul>
          <%= for account <- @accounts do %>
            <li class="mb-2">
              <strong><%= account.provider |> String.capitalize() %></strong>: {account.email}
              <button
                phx-click="remove_account"
                phx-value-id={account.id}
                class="ml-2 px-2 py-1 bg-red-500 text-white rounded"
              >
                Remove Account
              </button>
            </li>
          <% end %>
        </ul>
        <div class="mt-4">
          <%= unless Enum.any?(@accounts, fn account -> account.provider == "hubspot" end) do %>
            <button
              phx-click="add_hubspot_account"
              class="mb-2 px-4 py-2 bg-blue-500 text-white rounded"
            >
              Add HubSpot Account
            </button>
          <% end %>
          <button phx-click="add_google_account" class="px-4 py-2 bg-green-500 text-white rounded">
            Add Google Account
          </button>
        </div>
      </div>
      
    <!-- Main Content -->
      <div class="w-3/4 p-8">
        <div class="p-6">
          <h1 class="text-2xl font-bold mb-4">Scheduling Windows</h1>

          <%= if @windows != [] do %>
            <h2 class="text-xl font-semibold mb-2">Saved Time Slots</h2>
            <ul class="mb-6">
              <%= for w <- @windows do %>
                <li class="mb-2">
                  {"#{w.start_hour} - #{w.end_hour}"}
                  <button phx-click="remove" phx-value-id={w.id} class="text-red-500 ml-2">
                    Remove
                  </button>
                  <%= if !w.scheduling_link do %>
                    <button phx-click="configure" phx-value-id={w.id} class="text-blue-500 ml-2">
                      Configure Link
                    </button>
                  <% end %>

                  <%= if @configuring_id == w.id do %>
                    <.form :let={_f} for={%{}} as={:link} phx-submit="save_link">
                      <input type="hidden" name="link[window_id]" value={w.id} />
                      <div class="flex flex-col space-y-2 mt-2">
                        <input
                          type="number"
                          name="link[max_uses]"
                          placeholder="Max Uses (optional)"
                          class="border px-2"
                        />
                        <input type="date" name="link[expires_at]" class="border px-2" />
                        <textarea
                          name="link[questions]"
                          placeholder="Comma-separated questions"
                          class="border px-2"
                        ></textarea>
                        <input
                          type="number"
                          name="link[meeting_length]"
                          placeholder="Meeting Length (minutes)"
                          class="border px-2"
                          required
                        />
                        <input
                          type="number"
                          name="link[max_days_ahead]"
                          placeholder="Max Days Ahead to Book"
                          class="border px-2"
                          required
                        />
                        <button type="submit" class="bg-green-600 text-white px-3 py-1 rounded">
                          Save Link
                        </button>
                      </div>
                    </.form>
                  <% end %>

                  <%= if w.scheduling_link do %>
                    <div class="mt-1">
                      <input type="text" value={w.link_url} readonly class="border px-2 py-1 w-1/2" />
                    </div>
                  <% end %>
                </li>
              <% end %>
            </ul>
          <% end %>

          <h2 class="text-xl font-semibold mb-2">Add New Time Slot</h2>
          <.form :let={_f} for={%{}} as={:window} phx-submit="save">
            <div class="flex gap-4 mb-4">
              <input type="time" name="window[start_hour]" class="border px-2" />
              <input type="time" name="window[end_hour]" class="border px-2" />
              <select name="window[weekday]" class="border px-2">
                <%= for day <- ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday) do %>
                  <option value={day}>{day}</option>
                <% end %>
              </select>
              <button type="submit" class="bg-green-500 text-white px-4 py-1 rounded">Save</button>
            </div>
          </.form>

          <%= if @error do %>
            <p class="text-red-600">{@error}</p>
          <% end %>

          <h2 class="text-xl font-semibold mb-2">Scheduled Meetings</h2>
          <%= if @scheduled_meetings != [] do %>
            <ul class="mb-6">
              <%= for meeting <- @scheduled_meetings do %>
                <li class="mb-2">
                  <strong>Email:</strong> {meeting.email}<br />
                  <strong>LinkedIn:</strong> {meeting.linkedin || "N/A"}<br />
                  <strong>Scheduled At:</strong> {meeting.scheduled_at}<br />
                  <strong>Answers:</strong> {Enum.join(meeting.answers || [], ", ")}<br />
                  <strong>Context:</strong> {meeting.augmented_answer || "N/A"}
                </li>
              <% end %>
            </ul>
          <% else %>
            <p>No scheduled meetings found.</p>
          <% end %>
        </div>
        
    <!-- Display Google Calendar Events -->
        <div>
          <h2 class="text-lg font-bold mb-4">Google Calendar Events</h2>
          <ul>
            <%= for event <- @events do %>
              <li class="mb-2">
                <strong>{event["summary"] || "No Title"}</strong>
                <br /> Start: {event["start"]["dateTime"] || event["start"]["date"]}
                <br /> End: {event["end"]["dateTime"] || event["end"]["date"]}
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    user_id = Map.get(session, "user_id")

    cond do
      is_nil(user_id) ->
        {:ok, push_navigate(socket, to: "/")}

      true ->
        if connected?(socket),
          do: Phoenix.PubSub.subscribe(SchedlerApp.PubSub, "scheduled_meetings")

        # Fetch user token and expiry from the database
        user = Accounts.get_user!(user_id)
        user_token = user.google_token
        token_expiry = user.google_token_expires_at

        accounts =
          Accounts.get_user_accounts(user_id)
          |> Enum.reject(fn account ->
            if token_expired?(account.token_expires_at) do
              Accounts.delete_account(account.id)
              true
            else
              false
            end
          end)

        IO.inspect(accounts, label: "Accounts")

        events =
          accounts
          |> Enum.filter(fn account -> account.provider == "google" end)
          |> Enum.flat_map(&get_google_calendar_events/1)

        user_token_events = get_google_calendar_events_from_token(user_token)

        all_events = user_token_events ++ events

        windows =
          Scheduling.list_windows_with_links(user_id)
          |> inject_link_urls()

        scheduled_meetings = Scheduling.list_scheduled_meetings(user_id)

        {:ok,
         assign(socket,
           user_id: user_id,
           user_token: user_token,
           user_token_expires_at: token_expiry,
           accounts: accounts,
           events: all_events,
           windows: windows,
           scheduled_meetings: scheduled_meetings,
           new_window: %Window{},
           error: nil,
           configuring_id: nil
         )}
    end
  end

  @impl true
  def handle_info(:meeting_created, socket) do
    {:noreply,
     assign(
       socket,
       :scheduled_meetings,
       Scheduling.list_scheduled_meetings(socket.assigns.user_id)
     )}
  end

  def handle_event("remove_account", %{"id" => id}, socket) do
    case Accounts.get_account(id) do
      nil ->
        {:noreply, socket}

      account ->
        {:ok, _} = Accounts.delete_account(account.id)

        updated_accounts =
          Accounts.get_user_accounts(socket.assigns.user_id)
          |> Enum.reject(fn acc -> token_expired?(acc.token_expires_at) end)

        {:noreply, assign(socket, :accounts, updated_accounts)}
    end
  end

  @impl true
  def handle_event("add_google_account", _params, socket) do
    {:noreply, push_navigate(socket, to: "/auth/google")}
  end

  def handle_event("add_hubspot_account", _params, socket) do
    {:noreply, push_navigate(socket, to: "/auth/hubspot")}
  end

  def handle_event("save", %{"window" => params}, socket) do
    %{"start_hour" => start_hour, "end_hour" => end_hour, "weekday" => weekday} = params

    # Get the next date based on the weekday
    date = next_date(weekday)

    # Combine the date with start time and end time
    with {:ok, start_time} <- Time.from_iso8601(start_hour <> ":00"),
         {:ok, end_time} <- Time.from_iso8601(end_hour <> ":00") do
      # Convert the date and time into DateTime
      start_datetime = DateTime.new(date, start_time)
      end_datetime = DateTime.new(date, end_time)

      case {start_datetime, end_datetime} do
        {{:ok, start_dt}, {:ok, end_dt}} ->
          cond do
            DateTime.compare(end_dt, start_dt) != :gt ->
              {:noreply, assign(socket, :error, "End time must be after start time")}

            time_slot_clashes?(
              socket.assigns.windows,
              weekday,
              start_dt,
              end_dt,
              socket.assigns.events
            ) ->
              {:noreply, assign(socket, :error, "Time slot overlaps with existing window")}

            true ->
              Scheduling.create_window(%{
                start_hour: start_dt,
                end_hour: end_dt,
                weekday: weekday,
                user_id: socket.assigns.user_id
              })

              {:noreply,
               socket
               |> assign(
                 :windows,
                 inject_link_urls(Scheduling.list_windows_with_links(socket.assigns.user_id))
               )
               |> assign(:error, nil)}
          end

        _ ->
          {:noreply, assign(socket, :error, "Invalid datetime format")}
      end
    else
      _ -> {:noreply, assign(socket, :error, "Invalid time format")}
    end
  end

  def handle_event("remove", %{"id" => id}, socket) do
    case Scheduling.get_window!(id) do
      nil ->
        {:noreply, socket}

      window ->
        {:ok, _} = Scheduling.delete_window(window)

        {:noreply,
         assign(
           socket,
           :windows,
           inject_link_urls(Scheduling.list_windows_with_links(socket.assigns.user_id))
         )}
    end
  end

  def handle_event("configure", %{"id" => id}, socket) do
    {:noreply, assign(socket, :configuring_id, String.to_integer(id))}
  end

  def handle_event("save_link", %{"link" => link_params}, socket) do
    user_id = socket.assigns.user_id
    link_params = Map.put(link_params, "user_id", user_id)

    case Scheduling.create_scheduling_link(link_params) do
      {:ok, link} ->
        window = Scheduling.get_window!(link_params["window_id"])

        slots =
          try do
            generate_slots(
              window.start_hour,
              window.end_hour,
              link.meeting_length,
              link.max_uses,
              socket.assigns.windows,
              socket.assigns.events
            )
          rescue
            e ->
              IO.inspect(e, label: "Slot generation error")
              {:noreply, assign(socket, :error, "Failed to generate slots")}
          end

        IO.inspect(slots, label: "Generated Slots")

        Enum.each(slots, fn slot ->
          case Scheduling.create_slot(%{
                 utc_datetime: slot,
                 scheduling_link_id: link.id,
                 is_booked: false
               }) do
            {:ok, _slot} ->
              IO.puts("Slot created successfully")

            {:error, changeset} ->
              IO.inspect(changeset.errors, label: "Failed to create slot")
          end
        end)

        windows =
          Scheduling.list_windows_with_links(socket.assigns.user_id)
          |> inject_link_urls()

        {:noreply,
         socket
         |> assign(:windows, windows)
         |> assign(:configuring_id, nil)
         |> assign(:error, nil)}

      {:error, _changeset} ->
        {:noreply, assign(socket, :error, "Failed to save link")}
    end
  end

  defp time_slot_clashes?(existing_windows, weekday, start_time, end_time, all_events) do
    # Check for clashes with existing scheduling windows
    window_clash =
      Enum.any?(existing_windows, fn w ->
        w.weekday == weekday and
          DateTime.compare(end_time, w.start_hour) == :gt and
          DateTime.compare(start_time, w.end_hour) == :lt
      end)

    {:ok, start_dt} = DateTime.from_naive(start_time, "Etc/UTC")
    {:ok, end_dt} = DateTime.from_naive(end_time, "Etc/UTC")

    # Check for clashes with external calendar events
    event_clash =
      Enum.any?(all_events, fn event ->
        start_raw = event["start"]["dateTime"] || event["start"]["date"]
        end_raw = event["end"]["dateTime"] || event["end"]["date"]

        with {:ok, event_start_dt} <- parse_to_utc(start_raw),
             {:ok, event_end_dt} <- parse_to_utc(end_raw) do
          DateTime.compare(event_start_dt, end_dt) == :lt and
            DateTime.compare(event_end_dt, start_dt) == :gt
        else
          _ -> false
        end
      end)

    window_clash or event_clash
  end

  defp parse_to_utc(nil), do: {:error, :no_datetime}

  defp parse_to_utc(datetime_str) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, dt, _offset} ->
        {:ok, DateTime.shift_zone!(dt, "Etc/UTC")}

      {:error, _} ->
        case Date.from_iso8601(datetime_str) do
          {:ok, date} ->
            # Treat full-day events as starting at 00:00 UTC
            naive = NaiveDateTime.new!(date, ~T[00:00:00])
            DateTime.from_naive(naive, "Etc/UTC")

          _ ->
            {:error, :invalid_format}
        end
    end
  end

  defp inject_link_urls(windows) do
    Enum.map(windows, fn window ->
      if window.scheduling_link do
        Map.put(
          window,
          :link_url,
          Routes.schedule_url(SchedlerAppWeb.Endpoint, :show, window.scheduling_link.id)
        )
      else
        Map.put(window, :link_url, nil)
      end
    end)
  end

  defp next_date(weekday) do
    today = Date.utc_today()
    target_day = day_to_number(weekday)
    diff = rem(7 + target_day - Date.day_of_week(today), 7)
    next = if diff == 0, do: 7, else: diff
    Date.add(today, next)
  end

  defp day_to_number("Monday"), do: 1
  defp day_to_number("Tuesday"), do: 2
  defp day_to_number("Wednesday"), do: 3
  defp day_to_number("Thursday"), do: 4
  defp day_to_number("Friday"), do: 5
  defp day_to_number("Saturday"), do: 6
  defp day_to_number("Sunday"), do: 7

  defp token_expired?(nil), do: true

  defp token_expired?(expiry) do
    now = NaiveDateTime.utc_now()

    case expiry do
      %NaiveDateTime{} = dt -> NaiveDateTime.compare(now, dt) == :gt
      %DateTime{} = dt -> NaiveDateTime.compare(now, DateTime.to_naive(dt)) == :gt
      _ -> true
    end
  end

  defp get_google_calendar_events(%SchedlerApp.Accounts.Account{token: token})
       when is_binary(token) do
    get_google_calendar_events_from_token(token)
  end

  defp get_google_calendar_events_from_token(token) do
    client = OAuth2.Client.new(token: token)

    current_time = DateTime.utc_now() |> DateTime.to_iso8601()

    # Construct the URL to get only upcoming events
    url =
      "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=#{current_time}&orderBy=startTime&singleEvents=true"

    case OAuth2.Client.get(client, url) do
      {:ok, %{body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"items" => items}} ->
            items

          {:error, _reason} ->
            IO.puts("Failed to decode the response body.")
            []
        end

      {:error, reason} ->
        IO.inspect(reason, label: "Failed to fetch calendar events")
        []
    end
  end

  defp generate_slots(start_time, end_time, meeting_length, max_uses, existing_slots, all_events) do
    slots = generate_time_slots(start_time, end_time, meeting_length, existing_slots, all_events)

    if max_uses do
      Enum.take(slots, max_uses)
    else
      slots
    end
  end

  defp generate_time_slots(start_time, end_time, meeting_length, existing_slots, all_events) do
    generate_time_slots(start_time, end_time, meeting_length, existing_slots, all_events, [])
  end

  defp generate_time_slots(
         current_time,
         end_time,
         meeting_length,
         existing_slots,
         all_events,
         slots
       ) do
    if DateTime.compare(current_time, end_time) == :gt do
      Enum.reverse(slots)
    else
      next_time = DateTime.add(current_time, meeting_length * 60, :second)
      IO.inspect(current_time, label: "Current Time")
      IO.inspect(next_time, label: "Next Time")
      # Add the valid slot and continue
      generate_time_slots(next_time, end_time, meeting_length, existing_slots, all_events, [
        current_time | slots
      ])
    end
  end
end

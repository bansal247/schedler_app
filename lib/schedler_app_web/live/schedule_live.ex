defmodule SchedlerAppWeb.ScheduleLive do
  use Phoenix.LiveView
  alias SchedlerApp.Scheduling
  alias SchedlerApp.Accounts

  def render(assigns) do
    ~H"""
    <div class="p-6">
      <%= if @error do %>
        <p class="text-red-500">{@error}</p>
      <% else %>
        <h1 class="text-2xl font-bold">Book a Meeting</h1>
        <p>Meeting Length: {@link.meeting_length} minutes</p>

        <%= if @form_step == :select_slot do %>
          <h2>Available Slots:</h2>
          <ul>
            <%= for slot <- @slots do %>
              <li>
                <button phx-click="slot_id" phx-value-slot-id={slot.id}>
                  {slot.utc_datetime}
                </button>
              </li>
            <% end %>
          </ul>
        <% end %>

        <%= if @form_step == :enter_details do %>
          <h3>You selected: {@selected_slot.utc_datetime}</h3>

          <form phx-submit="submit_details">
            <div>
              <label for="email">Email:</label>
              <input type="email" id="email" name="email" required />
            </div>

            <div>
              <label for="linkedin">LinkedIn URL:</label>
              <input type="text" id="linkedin" name="linkedin" required />
            </div>

            <%= for question <- @questions do %>
              <div>
                <label for={question}>{question}</label>
                <textarea id={question} name={question}></textarea>
              </div>
            <% end %>

            <button type="submit">Submit</button>
          </form>
        <% end %>
      <% end %>
    </div>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    case Scheduling.get_scheduling_link(id) do
      nil ->
        {:ok, assign_error(socket, "Link not found")}

      %Scheduling.SchedulingLink{} = link ->
        cond do
          link_expired?(link) ->
            {:ok, assign_error(socket, "Link has expired")}

          link_not_active_yet?(link) ->
            {:ok, assign_error(socket, "Link not active yet")}

          true ->
            case Scheduling.get_slots_by_link_id(link.id) do
              {:error, reason} ->
                {:ok, assign_error(socket, reason)}

              slots ->
                available_slots = Enum.filter(slots, &(!&1.is_booked))
                questions = String.split(link.questions, ",")

                window = Scheduling.get_window!(link.window_id)

                {:ok,
                 assign(socket,
                   link: link,
                   window: window,
                   slots: available_slots,
                   questions: questions,
                   error: nil,
                   selected_slot: nil,
                   form_step: :select_slot
                 )}
            end
        end
    end
  end

  defp assign_error(socket, message) do
    assign(socket,
      error: message,
      link: nil,
      selected_slot: nil,
      form_step: :select_slot
    )
  end

  defp link_expired?(%{expires_at: nil}), do: false

  defp link_expired?(%{expires_at: expires_at}) do
    DateTime.new!(expires_at, ~T[23:59:59], "Etc/UTC") < DateTime.utc_now()
  end

  defp link_not_active_yet?(%{window_id: window_id, max_days_ahead: days}) do
    window = Scheduling.get_window!(window_id)
    DateTime.add(window.start_hour, -1 * days * 24 * 60 * 60, :second) > DateTime.utc_now()
  end

  def handle_event("slot_id", %{"slot-id" => id}, socket) do
    id = String.to_integer(id)
    selected_slot = Enum.find(socket.assigns.slots, &(&1.id == id))
    {:noreply, assign(socket, selected_slot: selected_slot, form_step: :enter_details)}
  end

  def handle_event(
        "submit_details",
        %{"email" => email, "linkedin" => linkedin} = params,
        socket
      ) do
    known_keys = ["email", "linkedin"]

    custom_answers =
      params
      |> Enum.reject(fn {key, _value} -> key in known_keys end)
      |> Enum.map(fn {_key, value} -> value end)

    hubspot_contact = get_hubspot_contact(email, socket.assigns.link.user_id)

    context =
      if hubspot_contact do
        Enum.map(hubspot_contact["properties"] || %{}, fn {k, v} -> "#{k}: #{v}" end)
        |> Enum.join("\n")
      else
        # Linkedin does not allow scrapping
        "I want to be helpful"
      end

    augmented_answer = augment_answer_with_context(custom_answers, context)

    attrs = %{
      email: email,
      linkedin: linkedin,
      scheduled_at: socket.assigns.selected_slot.utc_datetime,
      answers: custom_answers,
      scheduling_link_id: socket.assigns.link.id,
      user_id: socket.assigns.link.user_id,
      augmented_answer: augmented_answer
    }

    # get user from user_id
    user = Accounts.get_user!(socket.assigns.link.user_id)

    user =
      case DateTime.compare(user.google_token_expires_at, DateTime.utc_now()) do
        :lt ->
          {:ok, user} = Accounts.refresh_google_token(user)
          user

        _ ->
          user
      end

    token = user.google_token
    to = user.email

    case SchedlerApp.Mailer.send_email(token, to, attrs) do
      {:ok, _} ->
        # Email sent successfully
        :ok

      {:error, reason} ->
        IO.inspect(reason, label: "Email sending error")
    end

    case Scheduling.create_scheduled_meeting(attrs) do
      {:ok, _meeting} ->
        Scheduling.set_slot_booked(socket.assigns.selected_slot.id)

        # Broadcast the update
        Phoenix.PubSub.broadcast(
          SchedlerApp.PubSub,
          "scheduled_meetings",
          :meeting_created
        )

        {:noreply,
         assign(socket,
           form_step: :success,
           error: nil
         )}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           error: "Failed to save meeting: #{inspect(changeset.errors)}",
           form_step: :enter_details
         )}
    end
  end

  def get_hubspot_contact(email, user_id) do
    hubspot_account = Accounts.get_hubspot_account(user_id)

    if hubspot_account == nil do
      nil
    end

    hubspot_account =
      case DateTime.compare(hubspot_account.token_expires_at, DateTime.utc_now()) do
        :lt ->
          {:ok, hubspot_account} = Accounts.refresh_hubspot_token(hubspot_account)
          hubspot_account

        _ ->
          hubspot_account
      end

    url = "https://api.hubapi.com/crm/v3/objects/contacts/search"

    body = %{
      filterGroups: [
        %{
          filters: [
            %{propertyName: "email", operator: "EQ", value: email}
          ]
        }
      ]
    }

    headers = [
      {"Authorization", "Bearer #{hubspot_account.token}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.post(url, Jason.encode!(body), headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, decoded} ->
            List.first(decoded["results"] || [])

          {:error, decode_err} ->
            IO.inspect(decode_err, label: "JSON Decode Error")
            nil
        end

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        IO.puts("HubSpot API call failed with status: #{code}")
        IO.inspect(body, label: "Response body")
        nil

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("HTTPoison error:")
        IO.inspect(reason)
        nil
    end
  end

  defp augment_answer_with_context(answers, context) do
    prompt = """
    User Answer: #{Enum.join(answers, ", ")}
    Additional Context: #{context}
    Please combine these meaningfully. And don't show that you are AI. Just give me summary nothing else
    """

    body = %{
      model: "gpt-4.1",
      messages: [
        %{"role" => "system", "content" => "You are a helpful assistant."},
        %{
          "role" => "user",
          "content" => prompt
        }
      ],
      max_tokens: 100
    }

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{System.get_env("OPENAI_API_KEY")}"}
    ]

    case HTTPoison.post(
           "https://api.openai.com/v1/chat/completions",
           Jason.encode!(body),
           headers
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        response = Jason.decode!(response_body)
        response["choices"] |> List.first() |> Map.get("message") |> Map.get("content")

      {:error, _reason} ->
        "Failed to generate summary"
    end
  end
end

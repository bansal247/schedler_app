defmodule SchedlerApp.Mailer do
  @gmail_send_url "https://gmail.googleapis.com/gmail/v1/users/me/messages/send"

  def build_email_body(attrs) do
    answers_text =
      attrs.answers
      |> Enum.map(fn answer ->
        "- #{answer}"
      end)
      |> Enum.join("\n")

    augmented_section =
      if attrs.augmented_answer do
        "\n\nAdditional Context:\n" <> attrs.augmented_answer
      else
        ""
      end

    """
    Hi ,

    A meeting was scheduled for #{attrs.email}.

    Here are the details of your scheduled session:

    - Scheduled Time: #{attrs.scheduled_at}
    - LinkedIn Profile: #{attrs.linkedin}

    Answer Responses:
    #{answers_text}#{augmented_section}

    """
  end

  def send_email(token, to, attrs) do
    body = build_email_body(attrs)

    raw_email =
      """
      To: #{to}
      Subject: A meeting was scheduled
      Content-Type: text/plain; charset="UTF-8"

      #{body}
      """
      |> Base.encode64()
      # required by Gmail API
      |> String.replace("\n", "")

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    body = Jason.encode!(%{raw: raw_email})

    case HTTPoison.post(@gmail_send_url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        IO.puts("Email sent successfully!")
        IO.inspect(response_body, label: "Response Body")

        {:ok, "Email sent successfully"}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        IO.puts("Failed to send email. Status: #{status_code}")
        IO.inspect(response_body, label: "Error Response Body")
        {:error, "Failed to send email. Status: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("Error occurred while sending email: #{inspect(reason)}")
        {:error, "Error occurred while sending email: #{inspect(reason)}"}
    end
  end
end

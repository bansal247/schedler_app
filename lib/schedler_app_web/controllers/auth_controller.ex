defmodule SchedlerAppWeb.AuthController do
  use SchedlerAppWeb, :controller
  plug Ueberauth

  alias SchedlerApp.HubspotOauth
  alias SchedlerApp.Accounts

  def request(conn, %{"provider" => provider}) do
    case provider do
      "hubspot" ->
        redirect(conn, external: HubspotOauth.authorize_url!())

      "google" ->
        redirect(conn, external: Ueberauth.Strategy.Google.auth(conn))

      _ ->
        conn
        |> put_flash(:error, "Unknown provider")
        |> redirect(to: "/")
    end
  end

  def callback(conn, params) do
    %{"provider" => provider} = params

    case provider do
      "hubspot" ->
        handle_hubspot_callback(conn, params)

      "google" ->
        handle_google_callback(conn)

      _ ->
        conn
        |> put_flash(:error, "Unknown provider")
        |> redirect(to: "/")
    end
  end

  def handle_hubspot_callback(conn, %{"code" => code}) do
    response =
      HubspotOauth.get_token!(code: code)

    IO.inspect(response, label: "HubSpot OAuth2 Response")
    %OAuth2.Client{token: %OAuth2.AccessToken{access_token: raw_token}} = response

    # Decode the JSON string to extract the access token
    {:ok,
     %{"access_token" => token, "expires_in" => expires_in, "refresh_token" => refresh_token}} =
      Jason.decode(raw_token)

    user_id = get_session(conn, :user_id)

    if user_id do
      user = Accounts.get_user!(user_id)
      user_email = user.email

      hubspot_account_params = %{
        token: token,
        refresh_token: refresh_token,
        provider: "hubspot",
        user_id: user_id,
        email: user_email,
        token_expires_at: DateTime.utc_now() |> DateTime.add(expires_in, :second)
      }

      case Accounts.add_new_account(hubspot_account_params) do
        {:ok, _hubspot_account} ->
          conn
          |> put_flash(:info, "HubSpot account added successfully.")
          |> redirect(to: "/admin/dashboard")

        {:error, reason} ->
          IO.inspect(reason, label: "Error adding HubSpot account")

          conn
          |> put_flash(:error, "Failed to save HubSpot account: #{inspect(reason)}")
          |> redirect(to: "/")
      end
    else
      conn
      |> put_flash(:error, "User not logged in. Cannot add HubSpot account.")
      |> redirect(to: "/")
    end
  end

  def handle_google_callback(%{assigns: %{ueberauth_auth: auth}} = conn) do
    IO.inspect(auth, label: "Google OAuth2 Response")

    %Ueberauth.Auth{
      credentials: %{
        token: token,
        refresh_token: refresh_token,
        expires_at: expires_at
      },
      info: %{
        email: email,
        name: name
      },
      provider: provider,
      uid: uid
    } = auth

    user_params = %{
      email: email,
      name: name,
      provider: to_string(provider),
      uid: uid,
      google_token: token,
      google_refresh_token: refresh_token,
      google_token_expires_at: DateTime.from_unix!(expires_at)
    }

    user_id = get_session(conn, :user_id)

    if user_id != nil do
      user = Accounts.get_user!(user_id)
      user_email = user.email

      if user_email != email do
        user_params =
          user_params
          |> Map.put(:user_id, user_id)
          |> Map.put(:token, token)
          |> Map.put(:refresh_token, refresh_token)
          |> Map.put(:provider, "google")
          |> Map.put(:token_expires_at, DateTime.from_unix!(expires_at))

        IO.inspect(user_params, label: "adding google account")
        add_google_account(conn, user_params)
      end
    else
      IO.inspect(email, label: "logging in")
      login(conn, user_params)
    end
  end

  defp login(conn, user_params) do
    case Accounts.get_or_create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Successfully authenticated as #{user.email}")
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: "/admin/dashboard")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to save user: #{inspect(reason)}")
        |> redirect(to: "/")
    end
  end

  defp add_google_account(conn, user_params) do
    case Accounts.add_new_account(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Successfully added google user: #{user.email}")
        |> redirect(to: "/admin/dashboard")

      {:error, reason} ->
        IO.inspect(reason, label: "Error adding Google account")

        conn
        |> put_flash(:error, "Failed to save user: #{inspect(reason)}")
        |> redirect(to: "/")
    end
  end
end

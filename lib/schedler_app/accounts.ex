defmodule SchedlerApp.Accounts do
  import Ecto.Query, warn: false

  alias SchedlerApp.Repo
  alias SchedlerApp.Accounts.{User, Account}

  def get_or_create_user(attrs) do
    case Repo.get_by(User, email: attrs.email) do
      nil -> create_user(attrs)
      user -> update_user(user, attrs)
    end
  end

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def get_user!(id) do
    Repo.get!(User, id)
  end

  def get_account(id) do
    Repo.get(Account, id)
  end

  def delete_account(account_id) do
    case Repo.get(Account, account_id) do
      nil -> {:error, "Account not found"}
      account -> Repo.delete(account)
    end
  end

  def add_new_account(attrs) do
    IO.inspect(attrs, label: "add_new_account")

    case Repo.get_by(User, id: attrs.user_id) do
      nil ->
        {:error, "User not found"}

      user ->
        case Repo.get_by(Account, email: attrs.email) do
          nil -> add_account(user, attrs)
          account -> update_account(user, account, attrs)
        end
    end
  end

  def add_account(user, attrs) do
    %Account{}
    |> Account.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end

  def update_account(user, account, attrs) do
    account
    |> Repo.preload(:user)
    |> Account.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.update()
  end

  def get_hubspot_account(user_id) do
    Repo.get_by(Account, user_id: user_id, provider: "hubspot")
  end

  def get_user_accounts(user_id) do
    Repo.all(from a in Account, where: a.user_id == ^user_id)
  end

  def refresh_google_token(user) do
    client_id = System.get_env("GOOGLE_CLIENT_ID")
    client_secret = System.get_env("GOOGLE_CLIENT_SECRET")

    body = %{
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: user.google_refresh_token,
      grant_type: "refresh_token"
    }

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post("https://oauth2.googleapis.com/token", URI.encode_query(body), headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, token_data} = Jason.decode(body)

        updated_attrs = %{
          google_token: token_data["access_token"],
          google_token_expires_at: DateTime.add(DateTime.utc_now(), token_data["expires_in"])
        }

        user
        |> SchedlerApp.Accounts.User.changeset(updated_attrs)
        |> SchedlerApp.Repo.update()

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, "Failed to refresh token: #{status_code} - #{body}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  def refresh_hubspot_token(account) do
    client_id = System.get_env("HUBSPOT_CLIENT_ID")
    client_secret = System.get_env("HUBSPOT_CLIENT_SECRET")

    body = %{
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: account.refresh_token,
      grant_type: "refresh_token"
    }

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post("https://api.hubapi.com/oauth/v1/token", URI.encode_query(body), headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, token_data} = Jason.decode(body)

        updated_attrs = %{
          token: token_data["access_token"],
          token_expires_at: DateTime.add(DateTime.utc_now(), token_data["expires_in"])
        }

        account
        |> SchedlerApp.Accounts.Account.changeset(updated_attrs)
        |> SchedlerApp.Repo.update()

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, "Failed to refresh token: #{status_code} - #{body}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end
end

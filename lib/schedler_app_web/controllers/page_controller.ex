defmodule SchedlerAppWeb.PageController do
  use SchedlerAppWeb, :controller
  alias SchedlerApp.Accounts

  def home(conn, _params) do
    user_id = get_session(conn, :user_id)
    # get user from db and check if token is expired

    cond do
      is_nil(user_id) ->
        # Not logged in
        render(conn, :home, layout: false)

      true ->
        user = Accounts.get_user!(user_id)
        token_expiry = user.google_token_expires_at

        if token_expired?(token_expiry) do
          render(conn, :home, layout: false)
        else
          redirect(conn, to: ~p"/admin/dashboard")
        end
    end
  end

  defp token_expired?(nil), do: true

  defp token_expired?(expiry) do
    now = NaiveDateTime.utc_now()

    case expiry do
      %NaiveDateTime{} = dt ->
        NaiveDateTime.compare(now, dt) == :gt

      expiry_int when is_integer(expiry_int) ->
        # UNIX timestamp case
        DateTime.from_unix!(expiry_int)
        |> DateTime.to_naive()
        |> then(&(NaiveDateTime.compare(now, &1) == :gt))

      _ ->
        true
    end
  end
end

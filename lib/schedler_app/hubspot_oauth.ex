defmodule AdvisorScheduling.HubspotOauth do
  use OAuth2.Strategy

  @authorization_url "https://app.hubspot.com/oauth/authorize"
  @token_url "https://api.hubapi.com/oauth/v1/token"

  defp client_id, do: System.fetch_env!("HUBSPOT_CLIENT_ID")
  defp client_secret, do: System.fetch_env!("HUBSPOT_CLIENT_SECRET")
  defp redirect_uri, do: System.fetch_env!("REDIRECT_URI")

  def client do
    OAuth2.Client.new(
      strategy: __MODULE__,
      client_id: client_id(),
      client_secret: client_secret(),
      site: "https://api.hubapi.com",
      authorize_url: @authorization_url,
      token_url: @token_url,
      redirect_uri: redirect_uri()
    )
  end

  def authorize_url!(params \\ []) do
    client()
    |> put_param(:scope, "crm.objects.contacts.read")
    |> put_param(:redirect_uri, redirect_uri())
    |> put_param(:client_id, client_id())
    |> put_param(:client_secret, client_secret())
    |> OAuth2.Client.authorize_url!(params)
  end

  def get_token!(params \\ [], headers \\ []) do
    client()
    |> put_param(:redirect_uri, redirect_uri())
    |> put_param(:client_id, client_id())
    |> put_param(:client_secret, client_secret())
    |> OAuth2.Client.get_token!(params, headers)
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_header("Accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end

  def user_info!(token) do
    token
    |> OAuth2.Client.get!("https://api.hubapi.com/contacts/v1/me")
    |> Map.get(:body)
  end
end

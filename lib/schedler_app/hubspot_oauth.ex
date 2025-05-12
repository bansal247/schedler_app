defmodule SchedlerApp.HubspotOauth do
  use OAuth2.Strategy

  @authorization_url "https://app.hubspot.com/oauth/authorize"
  @token_url "https://api.hubapi.com/oauth/v1/token"

  def client do
    OAuth2.Client.new(
      strategy: __MODULE__,
      client_id: System.get_env("HUBSPOT_CLIENT_ID"),
      client_secret: System.get_env("HUBSPOT_CLIENT_SECRET"),
      site: "https://api.hubapi.com",
      authorize_url: @authorization_url,
      token_url: @token_url,
      redirect_uri: System.get_env("HUBSPOT_REDIRECT_URI")
    )
  end

  def authorize_url!(params \\ []) do
    client()
    |> put_param(:scope, "crm.objects.contacts.read")
    |> put_param(:redirect_uri, System.get_env("HUBSPOT_REDIRECT_URI"))
    |> put_param(:client_id, System.get_env("HUBSPOT_CLIENT_ID"))
    |> put_param(:client_secret, System.get_env("HUBSPOT_CLIENT_SECRET"))
    |> OAuth2.Client.authorize_url!(params)
  end

  def get_token!(params \\ [], headers \\ []) do
    client()
    |> put_param(:redirect_uri, System.get_env("HUBSPOT_REDIRECT_URI"))
    |> put_param(:client_id, System.get_env("HUBSPOT_CLIENT_ID"))
    |> put_param(:client_secret, System.get_env("HUBSPOT_CLIENT_SECRET"))
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

# SchedlerApp

## Setup
1. For Ueberauth these scopes are required in google cloud project `email profile https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/gmail.send`

2. Need `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `HUBSPOT_CLIENT_ID`, `HUBSPOT_CLIENT_SECRET`, `OPENAI_API_KEY` and `REDIRECT_URI` in env

3. Hubspot need `to_be_added` scopes
4. Openai api is using `gpt-4.1` model

## To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

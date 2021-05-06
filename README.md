# AbsintheClient

WIP adaption of Absinthe.Phoenix.Controller to be used with LiveView

Usage:

```elixir
defmodule MyApp.Web.WidgetsLive do
  use MyApp.Web, :live_view

  use AbsintheClient, schema: Bonfire.GraphQL.Schema, action: [mode: :internal]

  def mount(params, session, socket) do
    widgets = awesome_widgets(socket)
    IO.inspect(widgets)

    {:ok, socket
    |> assign(
      widgets: widgets
    )}
  end

  # notice we use snakecase rather than camelcase
  @graphql """
    {
      awesome_widgets
    }
  """
  def awesome_widgets(socket), do: graphql(socket, :awesome_widgets)

end
```

## License

See [LICENSE.md](./LICENSE.md).

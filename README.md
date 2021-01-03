# AbsintheClient

WIP adaption of Absinthe.Phoenix.Controller to be used with LiveView

Usage:

```elixir
defmodule MyApp.Web.WidgetsLive do
  use MyApp.Web, :live_view

  use AbsintheClient, schema: Bonfire.GraphQL.Schema, action: [mode: :internal]

  def mount(params, session, socket) do
    widgets = list_widgets(socket)
    IO.inspect(widgets)

    {:ok, socket
    |> assign(
      widgets: widgets.data
    )}
  end

  @graphql """
    {
      widgets
    }
  """
  def list_widgets(socket), do: graphql(socket, :list_widgets)

end
```

## License

See [LICENSE.md](./LICENSE.md).

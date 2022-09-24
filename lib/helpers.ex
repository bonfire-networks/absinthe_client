defmodule AbsintheClient.Helpers do
  require Logger

  def assign(%Plug.Conn{} = conn, key, val) do
    conn
    |> Plug.Conn.assign(key, val)
  end

  def assign(%Phoenix.LiveView.Socket{} = socket, key, val) do
    socket
    |> Phoenix.Component.assign(key, val)

    # |> IO.inspect
  end

  def assign(map, key, val) when is_map(map) do
    Map.merge(map, %{key => val})
  end

  def assign(nil, key, val) do
    %{key => val}
  end

  def assign(other, key, val) do
    Logger.error("AbsintheClient: expected a socket, conn, or map - got #{inspect(other)}")

    %{key => val}
  end

  def error(%Plug.Conn{} = conn, error) do
    conn |> Plug.Conn.send_resp(500, error)
  end

  def error(%Phoenix.LiveView.Socket{} = socket, error) do
    {:noreply, Phoenix.LiveView.put_flash(socket, :error, error)}
  end

  def maybe_to_atom(str) when is_binary(str) do
    try do
      String.to_existing_atom(str)
    rescue
      ArgumentError -> str
    end
  end

  def maybe_to_atom(other), do: other
end

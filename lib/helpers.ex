defmodule AbsintheClient.Helpers do

  def assign(%Plug.Conn{} = conn, key, val) do
    conn
    |> Plug.Conn.assign(key, val)
  end

  def assign(%Phoenix.LiveView.Socket{} = socket, key, val) do
    socket
    |> Phoenix.LiveView.assign(key, val)
    # |> IO.inspect
  end

  def error(%Plug.Conn{} = conn, error) do
    conn |> Plug.Conn.send_resp(500, error)
  end

  def error(%Phoenix.LiveView.Socket{} = socket, error) do
    {:noreply, Phoenix.LiveView.put_flash(socket, :error, error)}
  end

  def maybe_str_to_atom(str) when is_binary(str) do
    try do
      String.to_existing_atom(str)
    rescue
      ArgumentError -> str
    end
  end
  def maybe_str_to_atom(other), do: other

end

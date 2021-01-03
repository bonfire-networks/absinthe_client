defmodule AbsintheClient.Action do
  @moduledoc false

  @behaviour Plug
  @behaviour Absinthe.Phase

  alias Absinthe.{Blueprint, Phase}

  @impl Absinthe.Phase
  def run(bp, opts) do
    case internal?(bp, opts) do
      true ->
        {:swap, bp, Phase.Document.Result, AbsintheClient.Result}

      false ->
        {:insert, bp, normal_pipeline(opts)}
    end
  end

  # TODO: Refactor
  defp internal?(bp, opts) do
    opts[:action][:mode] == :internal ||
      with %{flags: flags} <- Blueprint.current_operation(bp) do
        Map.has_key?(flags, {:action, :internal})
      else
        _ -> false
      end
  end

  defp normal_pipeline(options) do
    [
      {Phase.Document.Validation.ScalarLeafs, options},
      {Phase.Document.Validation.Result, options}
    ]
  end

  @impl Plug
  @spec init(opts :: Keyword.t()) :: Keyword.t()
  def init(opts \\ []) do
    Map.new(opts)
  end

  @impl Plug
  def call(conn_or_socket, config) do
    controller = conn_or_socket.private.phoenix_controller
    document_provider = Module.safe_concat(controller, GraphQL)
    config = update_config(conn_or_socket, config)

    case document_and_schema(conn_or_socket, document_provider) do
      {document, schema} when not is_nil(document) and not is_nil(schema) ->
        execute(conn_or_socket, schema, controller, document, config)

      _ ->
        conn_or_socket
    end
  end

  defp update_config(conn_or_socket, config) do
    root_value =
      config
      |> Map.get(:root_value, %{})
      |> Map.merge(conn_or_socket.private[:absinthe][:root_value] || %{})

    context =
      config
      |> Map.get(:context, %{})
      |> Map.merge(extract_context(conn_or_socket))

    Map.merge(config, %{
      context: context,
      root_value: root_value
    })
  end

  defp extract_context(conn_or_socket) do
    conn_or_socket.private[:absinthe][:context] || %{}
  end


  defp execute(conn_or_socket, schema, controller, document, config) do
    variables = parse_variables(document, conn_or_socket.params, schema, controller)
    config = Map.put(config, :variables, variables)

    case Absinthe.Pipeline.run(document, pipeline(schema, controller, config)) do

      {:ok, %{result: result}, _phases} ->
        conn_or_socket
        |> assign(:absinthe_variables, conn_or_socket.params)
        |> Map.put(:params, result)

      {:error, msg, _phases} ->
        conn_or_socket
        |> error(msg)
    end
  end

  defp document_key(%{private: %{phoenix_action: name}}), do: to_string(name)
  defp document_key(_), do: nil


  defp document_and_schema(conn_or_socket, document_provider) do
    case document_key(conn_or_socket) do
      nil ->
        {nil, nil}

      key ->
        {
          Absinthe.Plug.DocumentProvider.Compiled.get(document_provider, key, :compiled),
          document_provider.lookup_schema(key)
        }
    end
  end

  defp pipeline(schema, controller, config) do
    options = Map.to_list(config)
    controller.absinthe_pipeline(schema, options)
  end

  defp parse_variables(document, params, schema, controller) do
    types = variable_types(document, schema)
    do_parse_variables(params, types, schema, controller)
  end

  defp do_parse_variables(params, variable_types, schema, controller) do
    for {name, raw_value} <- params, target_type = Map.get(variable_types, name), into: %{} do
      {
        name,
        controller.cast_param(raw_value, target_type, schema)
      }
    end
  end

  defp assign(%Plug.Conn{} = conn, key, val) do
    conn
    |> Plug.Conn.assign(:absinthe_variables, conn.params)
  end

  defp assign(%Phoenix.LiveView.Socket{} = socket, key, val) do
    socket
    |> Phoenix.LiveView.assign(:absinthe_variables, socket.params)
  end

  defp error(%Plug.Conn{} = conn, error) do
    conn |> Plug.Conn.send_resp(500, error)
  end

  defp error(%Phoenix.LiveView.Socket{} = socket, error) do
    {:noreply, Phoenix.LiveView.put_flash(socket, :error, error)}
  end

  @type_mapping %{
    Absinthe.Blueprint.TypeReference.List => Absinthe.Type.List,
    Absinthe.Blueprint.TypeReference.NonNull => Absinthe.Type.NonNull
  }

  # TODO: Extract this from here & Absinthe.Phase.Schema to a common function
  defp type_reference_to_type(%Absinthe.Blueprint.TypeReference.Name{name: name}, schema) do
    Absinthe.Schema.lookup_type(schema, name)
  end

  for {blueprint_type, core_type} <- @type_mapping do
    defp type_reference_to_type(%unquote(blueprint_type){} = node, schema) do
      inner = type_reference_to_type(node.of_type, schema)
      %unquote(core_type){of_type: inner}
    end
  end

  defp variable_types(document, schema) do
    for %{name: name, type: type} <-
          Absinthe.Blueprint.current_operation(document).variable_definitions,
        into: %{} do
      {name, type_reference_to_type(type, schema)}
    end
  end
end

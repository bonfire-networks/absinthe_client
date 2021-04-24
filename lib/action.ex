defmodule AbsintheClient.Action do
  @moduledoc false

  @behaviour Plug
  @behaviour Absinthe.Phase

  alias Absinthe.{Blueprint, Phase}
  alias AbsintheClient.Helpers

  @impl Absinthe.Phase
  def run(bp, opts) do
    case internal?(bp, opts) do
      true ->
        #IO.inspect(internal: true)
        {:swap, bp, Phase.Document.Result, AbsintheClient.Result}

      false ->
        #IO.inspect(internal: false)
        {:insert, bp, normal_pipeline(opts)}
    end
  end

  # TODO: Refactor
  defp internal?(bp, opts) do
    #IO.inspect(internal_opts: opts)
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
    querying_module = conn_or_socket.private.phoenix_controller
    call(conn_or_socket, querying_module, conn_or_socket.params, config)
  end

  # to be used manually (from AbsintheClient.graphql()), can run outside of Plug
  def call(conn_or_socket, querying_module, params, config) do
    document_provider = Module.safe_concat(querying_module, GraphQL)
    #IO.inspect(document_provider: document_provider)
    config = update_config(conn_or_socket, config)
    #IO.inspect(config: config)

    case document_and_schema(conn_or_socket, document_provider) do
      {action_name, document, schema} when not is_nil(document) and not is_nil(schema) ->
        # #IO.inspect(document: document)
        #IO.inspect(schema: schema)
        execute(conn_or_socket, schema, querying_module, action_name, document, params, config)

      _ ->
        #IO.inspect(document_and_schema: false)
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

  defp extract_context(%{assigns: assigns} = conn_or_socket) do
    # include assigns in context
    Map.merge(assigns, conn_or_socket.private[:absinthe][:context] || %{})
    # |> IO.inspect
  end

  defp extract_context(conn_or_socket) do
    conn_or_socket.private[:absinthe][:context] || %{}
  end


  def execute(conn_or_socket, schema, querying_module, _action_name, document, params, config) do
    variables = parse_variables(document, params, schema, querying_module)
    config = Map.put(config, :variables, variables)

    case Absinthe.Pipeline.run(document, pipeline(schema, querying_module, config)) do

      {:ok, %{result: result}, _phases} ->
        conn_or_socket
        |> Helpers.assign(:absinthe_variables, params)
        |> return_or_put(result)

      {:error, msg, _phases} ->
        #IO.inspect(error: msg)
        conn_or_socket
        |> Helpers.error(msg)
    end
  end

  def return_or_put(%Phoenix.LiveView.Socket{} = socket, val) do
    val
  end

  def return_or_put(%Plug.Conn{} = conn, val) do
    conn
        |> Map.put(:params, val)
  end

  defp document_key(%{assigns: %{phoenix_action: name}}), do: to_string(name)
  defp document_key(%{private: %{phoenix_action: name}}), do: to_string(name)
  defp document_key(%{assigns: %{private: %{phoenix_action: name}}}), do: to_string(name)
  defp document_key(p) do
    #IO.inspect(document_key: p)
     nil
  end
  defp document_key(_), do: nil


  defp document_and_schema(conn_or_socket, document_provider) do
    case document_key(conn_or_socket) do
      nil ->
        {nil, nil, nil}

      key ->
        {
          key,
          Absinthe.Plug.DocumentProvider.Compiled.get(document_provider, key, :compiled),
          document_provider.lookup_schema(key)
        }
    end
  end

  defp pipeline(schema, querying_module, config) do
    options = Map.to_list(config)
    querying_module.absinthe_pipeline(schema, options)
  end

  defp parse_variables(document, params, schema, querying_module) do
    types = variable_types(document, schema)
    do_parse_variables(params, types, schema, querying_module)
  end

  defp do_parse_variables(params, variable_types, schema, querying_module) do
    for {name, raw_value} <- params, target_type = Map.get(variable_types, name), into: %{} do
      {
        name,
        querying_module.cast_param(raw_value, target_type, schema)
      }
    end
  end


  @type_mapping %{
    Absinthe.Blueprint.TypeReference.List => Absinthe.Type.List,
    Absinthe.Blueprint.TypeReference.NonNull => Absinthe.Type.NonNull
  }

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

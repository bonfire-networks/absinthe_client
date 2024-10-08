defmodule AbsintheClient.ControllerTest do
  use ExUnit.Case, async: true
  use AbsintheClient.ConnCase, async: true

  defmodule Schema do
    use Absinthe.Schema

    query do
      field :string, :string do
        arg(:echo, :string)
        resolve(&resolve_echo/3)
      end

      field :integer, :integer do
        arg(:echo, :integer)
        resolve(&resolve_echo/3)
      end

      field :list_of_integers, list_of(:integer) do
        arg(:echo, list_of(:integer))
        resolve(&resolve_echo/3)
      end

      field :input_object_with_integers, :deep_integers do
        arg(:echo, :deep_integers_input)
        resolve(&resolve_echo/3)
      end
    end

    object :deep_integers do
      field(:foo, :integer)
      field(:bar, :integer)
      field(:baz, :integer)
    end

    input_object :deep_integers_input do
      field(:foo, :integer)
      field(:bar, :integer)
      field(:baz, :integer)
    end

    def resolve_echo(_, %{echo: echo}, _) do
      {:ok, echo}
    end
  end

  defmodule ReverseSchema do
    use Absinthe.Schema

    query do
      field :string, :string do
        arg(:echo, :string)
        resolve(&resolve_echo/3)
      end
    end

    def resolve_echo(_, %{echo: echo}, _) do
      {:ok, echo |> String.reverse()}
    end
  end

  defmodule Controller do
    use Phoenix.Controller

    use AbsintheClient,
      schema: AbsintheClient.ControllerTest.Schema,
      action: [mode: :internal]

    @graphql """
    query ($echo: String) { string(echo: $echo) }
    """
    def string(conn_or_socket, %{data: data}), do: json(conn_or_socket, data)
    def string(conn_or_socket, data), do: json(conn_or_socket, data)

    @graphql {"""
              query ($echo: String) { string(echo: $echo) }
              """, ReverseSchema}
    def reverse_string(conn_or_socket, data),
      do: json(conn_or_socket, data)

    @graphql """
    query ($echo: Int) { integer(echo: $echo) }
    """
    def integer(conn_or_socket, data), do: json(conn_or_socket, data)

    @graphql """
    query ($echo: [Int]) { list_of_integers(echo: $echo) }
    """
    def list_of_integers(conn_or_socket, data),
      do: json(conn_or_socket, data)

    @graphql """
    query ($echo: DeepIntegersInput) { input_object_with_integers(echo: $echo) }
    """
    def input_object_with_integers(conn_or_socket, data),
      do: json(conn_or_socket, data)
  end

  describe "input" do
    test "string" do
      assert %{"string" => "one"} ==
               result(Controller, :string, %{"echo" => "one"})
    end

    test "integer" do
      assert %{"integer" => 1} == result(Controller, :integer, %{"echo" => "1"})
    end

    test "list of integers" do
      assert %{"list_of_integers" => [1, 2, 3]} ==
               result(Controller, :list_of_integers, %{"echo" => ~w(1 2 3)})
    end

    test "input object with integers" do
      assert %{
               "input_object_with_integers" => %{
                 "foo" => 1,
                 "bar" => 2,
                 "baz" => 3
               }
             } ==
               result(Controller, :input_object_with_integers, %{
                 "echo" => %{"foo" => "1", "bar" => "2", "baz" => "3"}
               })
    end
  end

  describe "using an alternate schema" do
    test "can be defined using a @graphql tuple" do
      assert %{"string" => "eno"} ==
               result(Controller, :reverse_string, %{"echo" => "one"})
    end
  end

  def result(controller, name, params, verb \\ :get) do
    conn_or_socket = build_conn(verb, "/", params) |> Plug.Conn.fetch_query_params()

    controller.call(conn_or_socket, controller.init(name))
    |> json_response(200)
  end
end

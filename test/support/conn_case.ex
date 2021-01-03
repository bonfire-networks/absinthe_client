defmodule AbsintheClient.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest

      @endpoint AbsintheClient.TestEndpoint
    end
  end
end

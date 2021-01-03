defmodule AbsintheClient.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest

      # The default endpoint for testing
      @endpoint AbsintheClient.TestEndpoint
    end
  end
end

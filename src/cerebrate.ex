defmodule :cerebrate do
  @behavior :application

  def start() do
    Erlang.application.start :dnssd
    Erlang.application.start :cerebrate
  end

  def start(_type, _args) do
    IO.puts "Starting cerebrate"
    Cerebrate.Supervisor.start_link()
  end

  def stop(_state) do
    :ok
  end
end


defmodule Cerebrate do
  defmodule Supervisor do
    @behavior :supervisor

    def start_link() do
      Erlang.supervisor.start_link {:local, :cerebrate_sup}, Cerebrate.Supervisor, []
    end

    def init([]) do
      {:ok, {{:one_for_one, 10, 10}, [
        {
          :cerebrate_server, {CerebrateCollector, :start_link, []},
          :permanent, 60, :worker, [:cerebrate]
        }
      ]}}
    end
  end
end

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
          :cerebrate_server, {Cerebrate.Server, :start_link, []},
          :permanent, 60, :worker, [:cerebrate]
        }
      ]}}
    end
  end

  defmodule Server do
    def start_link() do
      {:ok, [[listen_port]]} = Erlang.init.get_argument(:port)
      args = [Erlang.erlang.list_to_integer(listen_port)]
      pid = spawn Cerebrate.Server, :start, args
      {:ok, pid}
    end

    def start(listen_port) do
      Erlang.dnssd.register "Cerebrate", "_cerebrate._udp", listen_port
      receive do
      match: {:dnssd, ref, {:register, :add, result}} 
        IO.puts "Registered #{inspect(result)}"
      match: {:dnssd, ref, {:register, :remove, result}}
        IO.puts "Unexpected remove result: #{inspect(result)}"
      end
      run Erlang.dict.store(:start_time, Erlang.now(), Erlang.dict.new())
    end

    def run(state) do
      IO.inspect CerebrateChecks.all()
      :ok = Erlang.timer.sleep 1000
      run state
    end
  end
end

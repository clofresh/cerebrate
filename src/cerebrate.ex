defmodule :cerebrate do
  @behavior :application

  def start() do
    Erlang.application.start :dnssd
    Erlang.application.start :cerebrate
  end

  def start(_type, _args) do
    IO.puts "Starting cerebrate"
    Erlang.cerebrate_sup.start_link()
  end

  def stop(_state) do
    :ok
  end
end

defmodule :cerebrate_sup do
  @behavior :supervisor

  def start_link() do
    Erlang.supervisor.start_link {:local, :cerebrate_sup}, :cerebrate_sup, []
  end

  def init([]) do
    {:ok, {{:one_for_one, 10, 10}, [
      {
        :cerebrate_server, {:cerebrate_server, :start_link, []},
        :permanent, 60, :worker, [:cerebrate]
      }
    ]}}
  end
end

defmodule :cerebrate_server do
  def start_link() do
    {:ok, [[listen_port]]} = Erlang.init.get_argument(:port)
    args = [Erlang.erlang.list_to_integer(listen_port)]
    pid = spawn :cerebrate_server, :start, args
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
    IO.inspect CerebrateChecks.loadavg()
    :ok = Erlang.timer.sleep 1000
    run state
  end

end



defmodule CerebrateChecks do
  def loadavg() do
    {:ok, line} = CerebrateUtils.raw_read_file "/proc/loadavg"
    [load1, load5, load15 | _rest] = Erlang.binary.split line, [" "], [:global]
    [{"system.load.1",  list_to_float(binary_to_list(load1))}, 
     {"system.load.5",  list_to_float(binary_to_list(load5))}, 
     {"system.load.15", list_to_float(binary_to_list(load15))}]
  end
end

defmodule CerebrateUtils do
  def raw_read_file(path) do
    {:ok, file} = Erlang.file.open path, [:read, :binary]
    raw_read_loop file, []
  end

  def raw_read_loop(file, acc) do
    case Erlang.file.read(file, 1024) do
    match: {:ok, bytes} 
      raw_read_loop file, [acc | bytes]
    match: eof
      Erlang.file.close file
      {:ok, iolist_to_binary acc}
    end
  end
end


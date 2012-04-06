defmodule CerebrateCollector do
  def start_link() do
    {:ok, [[listen_port]]} = Erlang.init.get_argument(:port)
    args = [Erlang.erlang.list_to_integer(listen_port)]
    pid = spawn CerebrateCollector, :start, args
    Process.register :collector, pid
    {:ok, pid}
  end

  def start(listen_port) do
    Erlang.dnssd.register "Cerebrate-#{listen_port}", "_cerebrate._udp", listen_port
    receive do
    match: {:dnssd, ref, {:register, :add, result}} 
      IO.puts "Registered #{inspect(result)}"
    match: {:dnssd, ref, {:register, :remove, result}}
      IO.puts "Unexpected remove result: #{inspect(result)}"
    end
    run Erlang.dict.store(:start_time, Erlang.now(), Erlang.dict.new())
  end

  def run(state) do
    check_data = CerebrateChecks.all()
    IO.inspect check_data
    receive do
    match: {:query, caller}
      caller <- check_data
    after: 1000
      IO.puts "No calls after 1000ms"
    end
    run state
  end
end


defmodule CerebrateChecks do
  def all() do
    loadavg()
  end

  def loadavg() do
    {:ok, line} = CerebrateChecks.Utils.raw_read_file "/proc/loadavg"
    [load1, load5, load15 | _rest] = Erlang.binary.split line, [" "], [:global]
    [{"system.load.1",  list_to_float(binary_to_list(load1))}, 
     {"system.load.5",  list_to_float(binary_to_list(load5))}, 
     {"system.load.15", list_to_float(binary_to_list(load15))}]
  end

  defmodule Utils do
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
end


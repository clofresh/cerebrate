defmodule CerebrateDnssd do
  @service_type "_cerebrate._tcp"
  @browse_timeout 1000

  def start_link(config) do
    pid = spawn_link CerebrateDnssd, :start, [config]
    Process.register :cerebrate_dnssd, pid
    {:ok, pid}
  end

  def start(config) do
    rpc_port = config[:rpc_port]
    Erlang.dnssd.register "Cerebrate-#{rpc_port}", CerebrateDnssd.__info__(:data)[:service_type], rpc_port
    receive do
    match: {:dnssd, ref, {:register, :add, result}} 
      IO.puts "Registered #{inspect(result)}"
    match: {:dnssd, ref, {:register, :remove, result}}
      IO.puts "Unexpected remove result: #{inspect(result)}"
    end
    run Erlang.dict.new()
  end

  def run(state) do
    new_state = Erlang.dict.store :peers, get_peers(), state
    #IO.inspect Erlang.dict.fetch :peers, new_state
    receive do
    match: {:query, caller}
      caller <- new_state
    after: 1000
      #IO.puts "No calls after 1000ms"
    end
    run new_state
  end


  @doc """
  Makes a dnssd browse request for all the services of type @service_type.
  Returns [{ServiceName, ServiceType, Domain}]
  """
  defp get_peers() do
    Erlang.dnssd.browse(CerebrateDnssd.__info__(:data)[:service_type])
    get_peers([])
  end

  defp get_peers(current_peers) do
    receive do
    match: {:dnssd, ref, {:browse, :add, result}}
      get_peers [result | current_peers]
    after: CerebrateDnssd.__info__(:data)[:browse_timeout]
      current_peers
    end
  end
end

defmodule CerebrateRpc do
  use GenServer.Behavior

  def start_link(config) do
    Erlang.gen_server.start_link({:local, :cerebrate_rpc}, __MODULE__, [config], [])
  end

  def init(_config) do
    IO.puts "Initialize CerebrateRpc gen_server"
    {:ok, []}
  end

  def handle_call(:check_data, _from, state) do
    {:reply, state, state}
  end

  def handle_cast(:run_checks, state) do
    {:noreply, CerebrateChecks.all()}
  end

  # API
  def run_checks() do
    Erlang.gen_server.cast(:cerebrate_rpc, :run_checks)
  end

  def check_data() do
    Erlang.gen_server.call(:cerebrate_rpc, :check_data)
  end

end

defmodule CerebrateCollector do
  def start_link(config) do
    pid = spawn_link CerebrateCollector, :start, [config]
    Process.register :collector, pid
    {:ok, pid}
  end

  def start(_config) do
    run
  end

  def run() do
    CerebrateRpc.run_checks()
    ok = Erlang.timer.sleep 2000
    run
  end
end


defmodule CerebrateChecks do
  def all() do
    loadavg()
  end

  def loadavg() do
    # First try Linux
    case CerebrateChecks.Utils.raw_read_file "/proc/loadavg" do
      match: {:ok, line}
        [load1, load5, load15 | _rest] = Erlang.binary.split line, [" "], [:global]
      match: {:error, :enoent} 
        # Now try OS X. Expecting something like:
        #   21:18  up 2 days, 12:22, 3 users, load averages: 1.55 1.62 1.60
        [_, _, _, _, _, _, _, _, _, _, load1, load5, load15_with_cr] = Erlang.binary.split list_to_binary(Erlang.os.cmd('uptime')), [" "], [:global]
        load15 = Regex.replace %r/\n/, load15_with_cr, ""
      end
      [{"system.load.1",  list_to_float(binary_to_list(load1))}, 
       {"system.load.5",  list_to_float(binary_to_list(load5))}, 
       {"system.load.15", list_to_float(binary_to_list(load15))}]
  end

  defmodule Utils do
    def raw_read_file(path) do
      case Erlang.file.open path, [:read, :binary] do
        match: {:ok, file}
          raw_read_loop file, []
        match: error = {:error, _reason}
          error
      end
    end

    def raw_read_loop(file, acc) do
      case Erlang.file.read(file, 1024) do
      match: {:ok, bytes} 
        raw_read_loop file, [acc | bytes]
      match: eof
        Erlang.file.close file
        {:ok, iolist_to_binary acc}
      match: error = {:error, _reason}
        error
      end
    end
  end
end


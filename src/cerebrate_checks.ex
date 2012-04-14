defmodule CerebrateRpc do
  @service_type "_cerebrate._tcp"
  @browse_timeout 50

  def start_link(config) do
    rpc_port = config[:rpc_port]
    Erlang.dnssd.register "Cerebrate-#{rpc_port}", __MODULE__.__info__(:data)[:service_type], rpc_port
    receive do
    match: {:dnssd, ref, {:register, :add, result}} 
      IO.puts "Registered #{inspect(result)}"
    match: {:dnssd, ref, {:register, :remove, result}}
      IO.puts "Unexpected remove result: #{inspect(result)}"
    end
    {:ok, Process.self()}
  end

  @doc """
  Makes a dnssd browse request for all the services of type @service_type,
  then connect to them as send the given command.
  """
  def query_peers(command) do
    Erlang.dnssd.browse(__MODULE__.__info__(:data)[:service_type])
    query_peers command, []
  end

  defp query_peers(command, data) do
    receive do
    match: {:dnssd, _ref, {:browse, :add, response={name, type, domain}}}
      # Found a peer, now get the port that it's listening on
      Erlang.dnssd.resolve name, type, domain
      query_peers command, data
    match: {:dnssd, _ref, {:resolve, response={domain_dot, port, _dns_data}}}
      # Resolved the port of a peer, now connect to it and send the query
      domain = binary_to_list(Regex.replace(%r/\.$/, domain_dot, ""))
      IO.puts "Connecting to #{inspect(domain)} #{inspect(port)}"
      {:ok, socket} = Erlang.gen_tcp.connect domain, port, [:binary, {:active, :true}]
      Erlang.gen_tcp.send socket, command
      query_peers command, data
    match: {:tcp, _port, new_data}
      # Received new data from a peer, append it to the list
      query_peers command, [new_data | data]
    match: {:tcp_closed, _port}
      # A peer closed the socket, probably ok
      query_peers command, data
    after: __MODULE__.__info__(:data)[:browse_timeout]
      # No messages after a few milliseconds, assume that everyone has 
      # reported in and return the data. 
      data
    end
  end

  # API

  def check_data() do
    query_peers "check_data"
  end

end

defmodule CerebrateRpcProtocol do
  def start_link(listener_pid, socket, transport, opts) do
    pid = spawn_link __MODULE__, :run, [listener_pid, socket, transport, opts]
    {:ok, pid}
  end

  def run(listener_pid, socket, transport, opts) do
    :ok = Erlang.cowboy.accept_ack(listener_pid)
    timeout = 10000
    case transport.recv(socket, 0, timeout) do
    match: {:ok, data}
      IO.puts "received data: #{data}"
      transport.send socket, inspect(CerebrateChecks.all())
    match: {:error, reason}
      IO.puts "Error: #{inspect reason}"
      transport.close(socket)
    end
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
        #[_, _, _, _, _, _, _, _, _, _, load1, load5, load15_with_cr] = Erlang.binary.split list_to_binary(Erlang.os.cmd('uptime')), [" "], [:global]
        #load15 = Regex.replace %r/\n/, load15_with_cr, ""
        {load1, load5, load15} = {<<"1.0">>, <<"2.0">>, <<"3.0">>}
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


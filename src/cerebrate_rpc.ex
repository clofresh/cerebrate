defmodule CerebrateRpc do
  @service_type "_cerebrate._tcp"
  @browse_timeout 50

  def start_link(config) do
    rpc_port = config[:rpc_port]
    Erlang.dnssd.register "Cerebrate-#{rpc_port}", __MODULE__.__info__(:data)[:service_type], rpc_port
    receive do
    match: {:dnssd, ref, {:register, :add, result}} 
      ExLog.info "Registered #{inspect(result)}"
    match: {:dnssd, ref, {:register, :remove, result}}
      ExLog.info "Unexpected remove result: #{inspect(result)}"
    end
    {:ok, Process.self()}
  end

  @doc """
  Makes a dnssd browse request for all the services of type @service_type,
  then connect to them as send the given command.
  """
  def query_peers(command) do
    ExLog.info "querying peers for #{command}"
    Erlang.dnssd.browse(__MODULE__.__info__(:data)[:service_type])
    query_peers command, [], Erlang.sets.new()
  end

  defp query_peers(command, data, seen_already) do
    receive do
    match: {:dnssd, _ref, {:browse, :add, response={name, type, domain}}}
      # Found a peer, now get the port that it's listening on
      Erlang.dnssd.resolve name, type, domain
      query_peers command, data, seen_already
    match: {:dnssd, _ref, {:resolve, response={domain_dot, port, _dns_data}}}
      # Resolved the port of a peer, now connect to it and send the query
      domain = binary_to_list(Regex.replace(%r/\.$/, domain_dot, ""))
      conn = {domain, port}
      case Erlang.sets.is_element(conn, seen_already) do
      match: :true
        ExLog.info "Skipping #{inspect(conn)}"
        query_peers command, data, seen_already
      match: :false
        ExLog.info "Connecting to #{inspect(conn)}"
        {:ok, socket} = Erlang.gen_tcp.connect domain, port, [:binary, {:active, :true}]        
        Erlang.gen_tcp.send socket, command
        query_peers command, data, Erlang.sets.add_element({domain, port}, seen_already)
      end
    match: {:tcp, _port, new_data}
      # Received new data from a peer, append it to the list
      ExLog.info "received new data: #{inspect(new_data)}"
      query_peers command, [new_data | data], seen_already
    match: {:tcp_closed, _port}
      # A peer closed the socket, probably ok
      query_peers command, data, seen_already
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
      response = inspect(CerebrateChecks.get_all())
      ExLog.info "received data: #{data}, responding with #{inspect(response)}"
      case transport.send(socket, response) do
      match: :ok
        :ok
      match: {:error, reason}
        ExLog.info "Send error: #{inspect(reason)}"
      end
    match: {:error, reason}
      ExLog.info "Error: #{inspect reason}"
      transport.close(socket)
    end
  end
end




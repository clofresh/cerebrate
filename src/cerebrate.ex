defmodule :cerebrate do
  @behavior :application

  def start() do
    Erlang.application.start :dnssd
    Erlang.application.start :cowboy
    Erlang.application.start :cerebrate
  end

  def start(_type, _args) do
    IO.puts "Starting cerebrate"

    # Get the ports from command line arguments
    [rpc_port, web_port] = Enum.map [:rpc_port, :web_port], fn(key) ->
      {:ok, [[val]]} = Erlang.init.get_argument key
      Erlang.erlang.list_to_integer val
    end
    config = [rpc_port: rpc_port, web_port: web_port]

    # Set up the cowboy web server
    dispatch = [
      {:'_', [{:'_', CerebrateWeb, [config]}]}
    ] 
    Erlang.cowboy.start_listener(:cerebrate_http_listener, 100,
      :cowboy_tcp_transport, [{:port, config[:web_port]}],
      :cowboy_http_protocol, [{:dispatch, dispatch}]
    )

    # Start the supervisor
    Cerebrate.Supervisor.start_link config
  end

  def stop(_state) do
    :ok
  end
end


defmodule Cerebrate do
  defmodule Supervisor do
    @behavior :supervisor

    def start_link(config) do
      Erlang.supervisor.start_link {:local, :cerebrate_sup}, Cerebrate.Supervisor, [config]
    end

    def init([config]) do
      {:ok, {{:one_for_one, 10, 10}, [
        {
          :cerebrate_server, {CerebrateCollector, :start_link, [config]},
          :permanent, 60, :worker, [:cerebrate]
        },
        {
          :cerebrate_dnssd, {CerebrateDnssd, :start_link, [config]},
          :transient, 60, :worker, [:cerebrate]
        },
        {
          :cerebrate_rpc, {CerebrateRpc, :start_link, [config]},
          :permanent, 60, :worker, [:cerebrate]
        }
      ]}}
    end
  end
end

defmodule CerebrateWeb do
  @behavior :cowboy_http_handler

  def init({_, :http}, req, [_config]) do
    {:ok, req, :undefined}
  end

  def handle(req, state) do
    data = CerebrateRpc.check_data

    output = Enum.map data, fn({metric, value}) ->  
      [metric, float_to_list(value)]
    end

    Process.whereis(:cerebrate_dnssd) <- {:query, Process.self()}
    peers = receive do
    match: dnssd_state
      Enum.map Erlang.dict.fetch(:peers, dnssd_state), fn({name, type, domain}) ->
        [name, type, domain]
      end
    after: 2000
      raise "Could not get peers"
    end
    IO.inspect peers
    reply = ["Data:", output, peers]
    IO.puts "replying with #{reply}"
    {:ok, req2} = Erlang.cowboy_http_req.reply(200, [], reply, req)

    {:ok, req2, state}
  end

  def terminate(_, _) do
    :ok
  end

end

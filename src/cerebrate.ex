defmodule :cerebrate do
  @behavior :application

  def start() do
    Erlang.application.start :dnssd
    Erlang.application.start :cowboy
    Erlang.application.start :cerebrate
  end

  def start(_type, _args) do
    ExLog.info "Starting cerebrate"

    # Get the ports from command line arguments
    [rpc_port, web_port] = Enum.map [:rpc_port, :web_port], fn(key) ->
      {:ok, [[val]]} = Erlang.init.get_argument key
      Erlang.erlang.list_to_integer val
    end
    config = [rpc_port: rpc_port, web_port: web_port, log_level: :info]

    # Set up the cowboy web server
    dispatch = [
      {:'_', [{:'_', CerebrateWeb, [config]}]}
    ] 
    Erlang.cowboy.start_listener(:cerebrate_http_listener, 100,
      :cowboy_tcp_transport, [{:port, config[:web_port]}],
      :cowboy_http_protocol, [{:dispatch, dispatch}]
    )
    Erlang.cowboy.start_listener(:cerebrate_rpc_listener, 100,
      :cowboy_tcp_transport, [{:port, config[:rpc_port]}],
      CerebrateRpcProtocol, []
    )

    # Start the supervisor
    CerebrateSupervisor.start_link config
  end

  def stop(_state) do
    :ok
  end
end


defmodule CerebrateSupervisor do
  @behavior :supervisor

  def start_link(config) do
    Erlang.supervisor.start_link {:local, :cerebrate_sup}, __MODULE__, [config]
  end

  def init([config]) do
    {:ok, {{:one_for_one, 10, 10}, [
      {
        :exlog, {ExLog, :start_link, [config]},
        :permanent, 60, :worker, [:cerebrate]
      },
      {
        :cerebrate_checks, {CerebrateChecks, :start_link, [config]},
        :permanent, 60, :worker, [:cerebrate]
      },
      {
        :cerebrate_rpc, {CerebrateRpc, :start_link, [config]},
        :permanent, 60, :worker, [:cerebrate]
      }
    ]}}
  end
end


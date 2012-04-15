defmodule Cerebrate do
  @behavior :application

  def start() do
    Erlang.application.start :dnssd
    Erlang.application.start :cowboy
    Erlang.application.start __MODULE__
  end

  def start(_type, _args) do
    # Parse the from command line arguments
    config = parse_args()
    IO.puts "Starting cerebrate with args: #{inspect(config)}"

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

  defp parse_args() do
    default_args = [rpc_port: 3456, web_port: 8080, log_level: :info]
    {raw_config, _other_args} = OptionParser.Simple.parse System.argv
    config = Enum.map default_args, fn({key, default_val}) ->
      val2 = case {key, raw_config[key]} do
      match: {key, nil}
        default_val
      match: {:rpc_port, val}
        Erlang.erlang.list_to_integer(binary_to_list(val))
      match: {:web_port, val}
        Erlang.erlang.list_to_integer(binary_to_list(val))
      match: {key, val}
        val
      end
      {key, val2}
    end
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
        :permanent, 60, :worker, [ExLog]
      },
      {
        :cerebrate_checks, {CerebrateChecks, :start_link, [config]},
        :permanent, 60, :worker, [CerebrateChecks]
      },
      {
        :cerebrate_rpc, {CerebrateRpc, :start_link, [config]},
        :permanent, 60, :worker, [CerebrateRpc]
      }
    ]}}
  end
end


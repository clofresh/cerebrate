defmodule :cerebrate do
  @behavior :application

  def start() do
    Erlang.application.start :dnssd
    Erlang.application.start :cowboy
    Erlang.application.start :cerebrate
  end

  def start(_type, _args) do
    IO.puts "Starting cerebrate"
    dispatch = [
      {:'_', [{:'_', CerebrateWeb, []}]}
    ] 
    Erlang.cowboy.start_listener(:cerebrate_http_listener, 100,
      :cowboy_tcp_transport, [{:port, 8080}],
      :cowboy_http_protocol, [{:dispatch, dispatch}]
    )
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

defmodule CerebrateWeb do
  @behavior :cowboy_http_handler

  def init({_, :http}, req, []) do
    {:ok, req, :undefined}
  end

  def handle(req, state) do
    Process.whereis(:collector) <- {:query, Process.self()}
    {:ok, req2} = receive do
    match: data
      output = Enum.map data, fn({metric, value}) ->  
        [metric, float_to_list(value)]
      end
      Erlang.cowboy_http_req.reply(200, [], ["Data:", output], req)
    after: 5000
      Erlang.cowboy_http_req.reply(500, [], "Timed out", req)
    end
    {:ok, req2, state}
  end

  def terminate(_, _) do
    :ok
  end

end

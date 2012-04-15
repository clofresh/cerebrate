defmodule CerebrateWeb do
  @behavior :cowboy_http_handler

  def init({_, :http}, req, [_config]) do
    {:ok, req, :undefined}
  end

  def handle(req, state) do
    data = CerebrateRpc.check_data
    IO.inspect data
    reply = ["Data:", data]
    ExLog.info "replying with #{reply}"
    {:ok, req2} = Erlang.cowboy_http_req.reply(200, [], reply, req)

    {:ok, req2, state}
  end

  def terminate(_, _) do
    :ok
  end

end

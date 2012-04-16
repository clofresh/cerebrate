defmodule CerebrateWeb do
  @behavior :cowboy_http_handler

  def init({_, :http}, req, [_config]) do
    filename = binary_to_list(:filename.absname("priv/index.html.dtl"))
    options = [{:out_dir, :filename.absname("ebin")}]
    :erlydtl.compile filename, :cerebrate_web_index, options
    {:ok, req, :undefined}
  end

  def handle(req, state) do
    {:ok, reply} = :cerebrate_web_index.render [{:data, CerebrateRpc.check_data}]
    {:ok, req2} = :cowboy_http_req.reply(200, [], reply, req)
    {:ok, req2, state}
  end

  def terminate(_, _) do
    :ok
  end

end

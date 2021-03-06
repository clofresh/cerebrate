defmodule CerebrateChecks do
  def start_link(config) do
    pid = spawn_link __MODULE__, :start, [config]
    {:ok, pid}
  end

  def start(_config) do
    ExLog.info "Starting Cerebrate checks"
    run {
      Port.open({:spawn, binary_to_list("python -u python/agent_port.py")}, [{:packet, 1}, :binary, :use_stdio]),
      :ets.new(:check_data, [:set, :public, :named_table])
    }
  end

  def run(state={port, table}) do
    agent_data = case check_agent(port) do
    match: {:error, reason}
      ExLog.error "CerebrateChecks exiting: #{inspect(reason)}"
    match: data
      data
    end
    :ets.insert table, update_ets(agent_data, [])
    ok = :timer.sleep 2000
    run state
  end

  def check_agent(port) do
    :true = Port.command(port, term_to_binary({:check}))
    receive do
    match: {port, {:data, data}}
      binary_to_term(data)
    after: 5000
      ExLog.error "Agent check timed out"
      {:error, :timeout}
    end
  end

  def update_ets([], processed_data) do
    ExLog.info "New check data: #{inspect(processed_data)}"
    processed_data
  end

  def update_ets([{key, val} | data], processed_data) do
    update_ets data, [{binary_to_atom(key), val} | processed_data]
  end

  def get_all() do
    :ets.tab2list :check_data
  end

end






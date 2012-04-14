defmodule CerebrateChecks do
  use GenServer.Behavior

  def start_link(config) do
    Erlang.gen_server.start_link({:local, :cerebrate_checks}, __MODULE__, [config], [])
  end

  def init(_config) do
    {:ok, []}
  end

  def handle_call(:data, _from, state) do
    {:reply, state, state}
  end

  def handle_cast(:update, state) do
    {:noreply, all()}
  end

  # API
  def data() do
    Erlang.gen_server.call(:cerebrate_checks, :data)
  end

  def update() do
    Erlang.gen_server.cast(:cerebrate_checks, :update)
  end

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
        [_, load1, load5, load15] = Regex.run %r/.*load averages: ([0-9.]*) ([0-9.]*) ([0-9.]*)/, list_to_binary(Erlang.os.cmd('uptime'))
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


defmodule CerebrateUpdater do
  def start_link(config) do
    pid = spawn_link CerebrateUpdater, :start, [config]
    {:ok, pid}
  end

  def start(_config) do
    run
  end

  def run() do
    CerebrateChecks.update()
    ok = Erlang.timer.sleep 2000
    run
  end
end


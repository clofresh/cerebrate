defmodule CerebrateChecks do
  def all() do
    loadavg()
  end

  def loadavg() do
    {:ok, line} = CerebrateChecks.Utils.raw_read_file "/proc/loadavg"
    [load1, load5, load15 | _rest] = Erlang.binary.split line, [" "], [:global]
    [{"system.load.1",  list_to_float(binary_to_list(load1))}, 
     {"system.load.5",  list_to_float(binary_to_list(load5))}, 
     {"system.load.15", list_to_float(binary_to_list(load15))}]
  end

  defmodule Utils do
    def raw_read_file(path) do
      {:ok, file} = Erlang.file.open path, [:read, :binary]
      raw_read_loop file, []
    end

    def raw_read_loop(file, acc) do
      case Erlang.file.read(file, 1024) do
      match: {:ok, bytes} 
        raw_read_loop file, [acc | bytes]
      match: eof
        Erlang.file.close file
        {:ok, iolist_to_binary acc}
      end
    end
  end
end


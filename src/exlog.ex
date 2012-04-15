defmodule ExLog do
	use GenServer.Behavior

	def start_link(config) do
		Erlang.gen_server.start_link {:local, :exlog}, __MODULE__, config, []
	end

	def init(args) do
		config = process_config args, []
		IO.puts "Starting ExLog with config #{inspect(config)}"
		{:ok, config}
	end

	defp process_config([], config) do
		config
	end

	defp process_config([head | rest], config) do
		case head do
		match: valid={:log_level, :debug}
			process_config rest, [valid | config]
		match: valid={:log_level, :info}
			process_config rest, [valid | config]
		match: valid={:log_level, :warn}
			process_config rest, [valid | config]
		match: valid={:log_level, :error}
			process_config rest, [valid | config]
		else:
			process_config rest, config
		end
	end

	defp should_log?(level, config) when is_list(config) do
		should_log? level, config[:log_level] || :info
	end

	defp should_log?(level, current_level) when is_atom(level) and is_atom(current_level) do
		enums = level_enums()
		should_log? enums[level], enums[current_level]
	end

	defp should_log?(level, current_level) when is_integer(level) and is_integer(current_level) do
		level >= current_level
	end

	defp level_enums() do
		[debug: 0, info: 10, warn: 20, error: 30]
	end

	def date() do
		{{year, month, day}, 
		 {hour, minute, second}} = Erlang.calendar.now_to_universal_time(:erlang.now())
		"#{year}-#{month}-#{day} #{hour}:#{minute}:#{second}"
	end

	def handle_cast({level, {from, message}}, config) do
		case should_log?(level, config) do
		match: :true
			IO.puts "#{date} - #{inspect(from)} - #{atom_to_binary(level)} - #{message}"
			{:noreply, config}			
		else:
			{:noreply, config}			
		end
	end

	def debug(message) do
		Erlang.gen_server.cast :exlog, {:debug, {Process.self(), message}}
	end

	def info(message) do
		Erlang.gen_server.cast :exlog, {:info, {Process.self(), message}}
	end
	
	def warn(message) do
		Erlang.gen_server.cast :exlog, {:warn, {Process.self(), message}}
	end
	
	def error(message) do
		Erlang.gen_server.cast :exlog, {:error, {Process.self(), message}}
	end

end
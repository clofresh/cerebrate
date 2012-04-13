task :default => [:build]

task :build => [:build_deps] do 
	sh "./deps/elixir/bin/elixirc -o ebin/ src/*.ex"
end

task :build_deps do
	sh "rebar get-deps compile"
	cd "deps/elixir" do |dir|
		sh "make"
	end
end

task :run, :rpc_port, :web_port do |task, args|
	rpc_port = args.rpc_port || 3456
	web_port = args.web_port || 8080
	sh "./bin/cerebrate -rpc_port #{rpc_port} -web_port #{web_port}"
end

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

task :run, :port do |task, args|
	port = args.port || 3456
	sh "./bin/cerebrate -port #{port}"
end

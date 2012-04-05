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

task :run do
	sh "erl -pa ebin/ -pa deps/*/ebin/ -pa deps/elixir/exbin/ -s cerebrate -port 3456"
end

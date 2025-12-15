-- Worst code i have written in years.... For the love of the game

exit = os.exit;
require "parser.printing";

local loading = require "parser.init";

function readline(prompt)
	-- TODO: add random timeout
	-- print("Thinking...");
	-- if not os.execute "uname" then
	-- 	os.execute("timeout " .. math.random(0, 3));
	-- else
	-- 	os.execute("sleep " .. math.random(0, 3));
	-- end

	io.stderr:write(prompt);

	return io.read "l";
end;

(package.loaders or package.searchers)[2] = loading.mod_searcher;
load = loading.load;
function loadfile(name)
	return load(io.lines(name, 4096), "@" .. name);
end

local err_tag = {};

local function run(l)
	local ok, func = pcall(load, l, "=stdin.forgo\nr");
	if not ok then
		return { [err_tag] = func };
	end

	return func();
end
local function run_file(name)
	local f = assert(io.open(name, "r"));
	local src = f:read "a";
	f:close();

	local ok, func = pcall(load, src, "@" .. name, "t");
	if not ok then
		return { [err_tag] = func };
	end

	return func();
end

local ok, err = pcall(function ()
	if arg[1] then
		local err = run_file(arg[1]);
		if err and err[err_tag] then
			print(err[err_tag]);
		end
	else
		print "I would tell you the welcome message, but I forgor...";
		for l in io.stdin:lines "l" do
			local err = run(l);
			if err and err[err_tag] then
				print(err[err_tag]);
			end
		end
	end

end);

if not ok then
	print("there is an error but i forgor :(");
end

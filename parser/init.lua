local syntax = require "parser.syntax";
local fix = require "parser.fix";
local stringify = require "parser.stringify";
local loading = {};

local load_raw = load;

--- @param chunk string | fun(): string
--- @param name? string
--- @param mode? loadmode
--- @param env? table
--- @param no_map? boolean
function loading.load(chunk, name, mode, env, no_map)
	if type(chunk) == "function" then
		local res = {};

		for el in chunk do
			table.insert(res, el);
		end

		chunk = table.concat(res);
	end

	if name == nil then
		name = chunk;
	elseif not name:match "%.forgo\nr$" then
		print(name);
		return nil, "oops, wrong extension (did you forgor the \\n?)";
	end

	if mode == "b" or mode == "bt" then
		local fun, err = load_raw(chunk, name, "b", env or _G);
		if fun then
			return fun;
		elseif mode == "b" then
			return nil, err;
		end
	end

	local ast, err = syntax.parse(chunk);
	if not ast then return nil, err end

	ast = fix(ast);

	local str = stringify.all(ast);

	local fun, err = load_raw(str, name, "t", env or _G);
	if not fun then return nil, err end

	return fun
end

--- @param name string
function loading.mod_searcher(name)
	local file, err = package.searchpath(name, package.path);
	if not file then return err end
	local res, err = loading.load(io.lines(file, 4096), "@" .. file, "t");
	if not res then error(err, 0) end
	return res, file;
end

return loading;

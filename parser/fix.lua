local nodes = require "parser.node";
local syntax = require "parser.syntax";

--- @class forgor.fix.ctx
--- @field parts node.stm[]
--- @field id_base string
--- @field next_id integer
--- @field polyfills table<string, string> A table polyfill name -> polyfill
--- @field scope forgor.fix.scope

--- @class forgor.fix.scope
--- @field prev forgor.fix.scope?
--- @field names table<string, boolean>
--- @field consts table<string, boolean>

--- @type table<string, fun(self: forgor.fix.ctx, node: node): node>
local walkers = {};

local interop_funcs = {
	[nodes.ops.POW] = syntax.parse_exp("math.pow", true),

	[nodes.ops.B_NEG] = syntax.parse_exp("bit.bnot", true),
	[nodes.ops.IDIV] = syntax.parse_exp([[function (a, b)
		return math.floor(a / b);
	end]], true), -- TODO: to be done

	[nodes.ops.B_SHL] = syntax.parse_exp("bit.lshift", true),
	[nodes.ops.B_SHR] = syntax.parse_exp("bit.rshift", true),
	[nodes.ops.B_AND] = syntax.parse_exp("bit.band", true),
	[nodes.ops.B_OR] = syntax.parse_exp("bit.bor", true),
	[nodes.ops.B_XOR] = syntax.parse_exp("bit.bxor", true),
};
local polyfills = {
	getfenv = syntax.parse_exp("getfenv", true),
	setfenv = syntax.parse_exp("setfenv", true),
	set_var = assert(syntax.parse_exp([[function (name, ...)
		print("Remember that variable(s) " .. name .. " are/is " .. table.concat({ ... }, ", "));
	end]], true)),
	get_var = assert(syntax.parse_exp([[function (name, val)
		local res = readline("What was " .. name .. "'s value? ");
		return tonumber(res) or res;
	end]], true)),
};

--- @param self forgor.fix.ctx
--- @param name string
--- @param node node.exp
local function polyfill(self, name, node)
	if self.polyfills[name] then
		return self.polyfills[name];
	end

	local id = self.id_base .. "_" .. self.next_id;
	self.next_id = self.next_id + 1;

	self.polyfills[name] = id;

	table.insert(self.parts, nodes.decl(nil, false, { id }, { node }));

	return id;
end

--- @generic T: node
--- @param self forgor.fix.ctx
--- @param node T
--- @return T
local function walk(self, node)
	--- @cast node node
	local res = walkers[node.type];
	if not res then error("node '" .. node.type .. "' not walkable", 2) end

	return res(self, node);
end

--- @param self forgor.fix.ctx
--- @param nodes node[]
--- @return node[]
local function walk_all(self, nodes)
	for i = 1, #nodes do
		nodes[i] = walk(self, nodes[i]);
	end

	return nodes;
end

--- @param node node.var
function walkers.var(self, node)
	return nodes.call(node.loc, nodes.var(node.loc, polyfill(self, "get_var", polyfills.get_var)), nodes.str(node.loc, node.name));
end
function walkers.str(self, node) return node end
function walkers.bool(self, node) return node end
function walkers.int(self, node) return node end
function walkers.fl(self, node) return node end
function walkers.args(self, node) return node end
walkers["nil"] = function (self, node) return node end
--- @param node node.paren
function walkers.paren(self, node)
	node.val = walk(self, node.val);
	return node;
end
--- @param node node.table
function walkers.table(self, node)
	error("tables are too complex, let's try something simpler", 0);
end
--- @param node node.func
function walkers.func(self, node)
	error("NO CHEATING YOU DO NOT NEED FUNCTIONS!!!!", 0);
end
--- @param node node.op
function walkers.op(self, node)
	node.a = walk(self, node.a);
	node.b = node.b and walk(self, node.b);

	local func = interop_funcs[node.op];
	if not func then return node end

	local id = polyfill(self, "operator_" .. node.op, func);

	return nodes.call(nil, nodes.var(nil, id), node.a, node.b);
end

--- @param node node.call
function walkers.call(self, node)
	local curr = node.func;

	while true do
		if curr.type == "var" then
			break;
		elseif curr.type == "index" then
			curr = curr.val;
		else
			error("NO CHEATING!!", 0);
		end
	end

	if node.func.type ~= "var" then
		node.func = walk(self, node.func);
	end

	walk_all(self, node);

	return node;
end
--- @param node node.method
function walkers.method(self, node)
	node.obj = walk(self, node.obj);
	walk_all(self, node);
	return node;
end
--- @param node node.index
function walkers.index(self, node)
	node.obj = walk(self, node.obj);
	node.key = walk(self, node.key);
	return node;
end

--- @param node node.decl
function walkers.decl(self, node)
	error("you don't *need* declarations, you have the rememorour to rememour for you!", 0);
end
--- @param node node.assign
function walkers.assign(self, node)
	local names = {};

	for i = 1, #node.targets do
		if node.targets[i].type ~= "var" then
			error("this code is too complex, the rememorour might get confused...", 0);
		end

		table.insert(names, node.targets[i].name);
	end

	return nodes.call(node.loc, nodes.var(node.loc, polyfill(self, "set_var", polyfills.set_var)), nodes.str(node.loc, table.concat(names, ", ")), table.unpack(walk_all(self, node.values)));
end
--- @param node node.if
walkers["if"] = function (self, node)
	walk_all(self, node.conds);
	for i = 1, #node.bodies do
		walk_all(self, node.bodies[i]);
	end

	if node.default then
		walk_all(self, node.default);
	end

	return node;
end
--- @param node node.while
walkers["while"] = function (self, node)
	node.cond = walk(self, node.cond);
	walk_all(self, node.body);
	return node;
end
--- @param node node.while
walkers["repeat"] = function (self, node)
	walk_all(self, node.body);
	node.cond = walk(self, node.cond);
	return node;
end
--- @param node node.for
walkers["for"] = function (self, node)
	error("NO CHEATING!", 0);
end
--- @param node node.for_in
function walkers.for_in(self, node)
	error("NO CHEATING!", 0);
end
--- @param node node.scope
function walkers.scope(self, node)
	walk_all(self, node.body);
	return node;
end

--- @param node node.return
walkers["return"] = function (self, node)
	walk_all(self, node);
	return node;
end
--- @param node node.break
walkers["break"] = function (self, node)
	return node;
end

--- @param nodes node.stm[]
--- @return node.stm[]
return function (nodes)
	--- @type forgor.fix.ctx
	local ctx = {
		id_base = "_" .. math.random(1, 0x1000000),
		next_id = 1,
		parts = {},
		polyfills = {},
		scope = { prev = nil, consts = {}, names = {} },
	};

	nodes = walk_all(ctx, nodes);

	table.move(nodes, 1, #nodes, #ctx.parts + 1);
	table.move(ctx.parts, 1, #ctx.parts, 1, nodes);

	return nodes;
end

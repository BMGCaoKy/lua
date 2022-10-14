local Cache = require "editor.gamedata.cache"
local Misc = require "misc"
local Core = require "editor.core"
local Meta = require "editor.gamedata.meta.meta"
local Def = require "editor.def"
local Converter = require "editor.gamedata.export.data_converter"

local ext = {
	json = function(data)
		return Lib.toJson(data)
	end,

	csv = function(data, header)
		header = header or {}
		if #header == 0 then
			local keys = {}
			for _, item in ipairs(data) do
				for k in pairs(item) do
					keys[k] = true
				end
			end
			for k in pairs(keys) do
				table.insert(header, k)
			end
			table.sort(header)
		end

		local function to_array(item)
			local ret = {}
			for _, key in pairs(header) do
				table.insert(ret, item[key])
			end
			return ret
		end

		local out_tb = {}
		table.insert(out_tb, Misc.csv_encode(header))
		for _, v in ipairs(data) do
			local line = to_array(v)
			table.insert(out_tb, Misc.csv_encode(line))
		end
		table.insert(out_tb, "")
		local out = table.concat(out_tb, "\r\n")
		return Core.to_utf16(out)
	end,

	bts = function(triggers)
		local nodes = {}
		local parse_action

		local function parse_node(id)
			local node = nodes[id]
			if node then
				return parse_action(node)
			end
		end

		local function parse_param_value(data)
			return Converter(data)
		end

		local function parse_comp_params(comp, action)
			assert(not action.funcs)
			assert(not action.params)

			action.funcs = {}
			action.params = {}

			for _, param in ipairs(comp.params) do
				local id = param.value.action
				if id and id ~= "" then
					action.funcs[param.key] = parse_node(id)
				else
					action.params[param.key] = parse_param_value(param.value and param.value.rawval)
				end
			end
		end

		local function parse_comp_context(comp, action)
			assert(not action.params)

			action.params = {}
			action.params["key"] = comp.key
		end

		local function parse_comp_sequence(comp, action)
			assert(not action.children)

			action.children = {}
			for _, child in ipairs(comp.children) do
				local tmp = parse_node(child.action)
				if tmp then
					table.insert(action.children, tmp)
				end
			end
		end

		local function parse_comp_condition(comp, action)
			assert(not action.children)

			action.children = {}
			for _, child in ipairs(comp.children) do
				local tmp = parse_node(child.action)
				if tmp then
					table.insert(action.children, tmp)
				end
			end
		end

		parse_action = function(action)
			local ret = {}

			ret["type"] = action.name

			for _, comp in ipairs(action.components or {}) do
				local comp_type = comp[Def.OBJ_TYPE_MEMBER]
				if comp_type == "Component_Params" then
					parse_comp_params(comp, ret)
				elseif comp_type == "Component_Context" then
					parse_comp_context(comp, ret)
				elseif comp_type == "Component_Function_Param" then
					parse_comp_context(comp, ret)
				elseif comp_type == "Component_Sequence" then
					parse_comp_sequence(comp, ret)
				elseif comp_type == "Component_Condition" then
					parse_comp_condition(comp, ret)
				else
					assert(false, string.format("invalid commponent %s", comp_type))
				end
			end

			return ret
		end

		local function parse_trigger(trigger)
			local ret = {}
			
			for _, action in ipairs(trigger.actions) do
				nodes[action.id.value] = action
			end

			ret["type"] = function()
				local meta = Meta:meta(trigger.type)
				assert(meta, string.format("invalid type %s", trigger.type))

				local val = meta:ctor()
				return val.name
			end

			ret["actions"] = function()
				local ret = {}

				assert(trigger.root.name == "Parallel")
				local root = parse_action(trigger.root)
				for _, action in ipairs(root.children) do
					table.insert(ret, action)
				end

				return ret
			end

			local key, val = next(ret)
			while(key) do
				if type(val) == "function" then
					ret[key] = val()
				end
				key, val = next(ret, key)
			end

			return ret
		end

		local ret = {}

		if not triggers then
			return ""
		end
		
		for _, trigger in ipairs(triggers.list or {}) do
			table.insert(ret, parse_trigger(trigger))
		end

		local loader = loadfile(
			package.searchpath("editor.gamedata.export.dumper", package.path),
			"bt",
			setmetatable({}, {__index = _G})
		)

		local dumper = loader()
		local r1, r2 = pcall(dumper, ret)
		if not r1 then
			return ""
		end
		return r2
	end,
}

return function(format, data, path, dump, ...)
	local processor = assert(ext[format], string.format("not suppert that format %s", tostring(format)))
	local content = processor(data, ...)
	assert(content, string.format("seri error:\n%s", tostring(content)))

	local dir = string.match(path, "^(%g*)/%g+$")
	if dump then
		Lib.mkPath(dir)
		local file = io.open(path, "w+b")
		file:write(content)
		file:close()
	else
		Cache:add(path, content)
	end
end

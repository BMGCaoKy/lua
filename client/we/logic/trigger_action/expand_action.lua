local Def = require "we.def"

local group_list = {}

local function init(groups)
	group_list = groups
end

local function transfrom_pos(actions,pos)
	local pos_x = {}
	local pos_y = {}
	for _,action in pairs(actions) do
		table.insert(pos_x, action.pos.x)
		table.insert(pos_y, action.pos.y)
	end
	local min_x = math.min(table.unpack(pos_x))
	local max_x = math.max(table.unpack(pos_x))
	local min_y = math.min(table.unpack(pos_y))
	local max_y = math.max(table.unpack(pos_y))
	local centre_x = (min_x + max_x)/2
	local centre_y = (min_y + max_y)/2

	for _,action in pairs(actions) do
		local vx = action.pos.x - centre_x
		local vy = action.pos.y - centre_y

		action.pos.x = pos.x + vx
		action.pos.y = pos.y + vy
	end
end

local function parse_params(comp,connect_mapping)
	for _,param in ipairs(comp.params or {}) do
		local action = param.value.action
		if connect_mapping[action] then
			param.value.action = connect_mapping[action]
		end
	end
end

local function parse_sequence(comp,connect_mapping)
	for _,child in ipairs(comp.children) do
		local action = child.action
		if connect_mapping[action] then
			child.action = connect_mapping[action]
		end
	end
end

local function parse_condition(comp,connect_mapping)
	for _,child in ipairs(comp.children) do
		local action = child.action
		if connect_mapping[action] then
			child.action = connect_mapping[action]
		end
	end
end

local function parse_script(comp,connect_mapping)
	for _,child in ipairs(comp.children) do
		local action = child.action
		if connect_mapping[action] then
			child.action = connect_mapping[action]
		end
	end
end

local function transfrom_action(action,connect_mapping)
	for _,comp in ipairs(action.components or {}) do
		local comp_type = comp[Def.OBJ_TYPE_MEMBER]
		if comp_type == "Component_Params" then
			parse_params(comp,connect_mapping)
		elseif comp_type == "Component_Context" then
			
		elseif comp_type == "Component_Function_Param" then
			
		elseif comp_type == "Component_Sequence" then
			parse_sequence(comp,connect_mapping)
		elseif comp_type == "Component_Condition" then
			parse_condition(comp,connect_mapping)
		elseif comp_type == "Component_Script" then
			parse_script(comp,connect_mapping)
		else
			assert(false, string.format("invalid commponent %s", comp_type))
		end
	end
end

local function expand_node()
	local ret = {}
	for _,group in ipairs(group_list) do
		transfrom_pos(group.actions,group.pos)
		
		local connect_mapping = {}
		for _,port in ipairs(group.import_node.ports) do
			local id = port.id
			local action = port.param.value.action
			connect_mapping[id] = action
		end


		for _,action in ipairs(group.actions) do
			transfrom_action(action,connect_mapping)
			local data = {}
			data.type = action[Def.OBJ_TYPE_MEMBER]
			data.node = action
			table.insert(ret,data)
		end
	end
	return ret
end

return {
	init = function(groups)
		return init(groups)
	end,

	expand = function()
		return expand_node()
	end
}
local Meta = require "we.gamedata.meta.meta"
local Lang = require "we.gamedata.lang"
local Def = require "we.def"

local node_list = {}
local node_group = {}

local function init(nodes)
	node_list = nodes
	local type = "Node_CollapseGraph"
	local meta = Meta:meta(type)
	assert(meta, type)
	node_group = meta:ctor()
end

local function transfrom_name()
	local key = node_group.name.value
	--todo
	Lang:set_text(key, "Node_CollapseGraph")
end

local function transfrom_pos()
	local pos_x = {}
	local pos_y = {}
	for _,val in pairs(node_list) do
		local action = val["node"]
		table.insert(pos_x, action.pos.x)
		table.insert(pos_y, action.pos.y)
	end
	local min_x = math.min(table.unpack(pos_x))
	local max_x = math.max(table.unpack(pos_x))
	local min_y = math.min(table.unpack(pos_y))
	local max_y = math.max(table.unpack(pos_y))
	local centre_x = (min_x + max_x)/2
	local centre_y = (min_y + max_y)/2

	node_group.pos.x = centre_x
	node_group.pos.y = centre_y
end

local function parse_params(comp,node_params)
	for _,param in ipairs(comp.params or {}) do
		local action = param.value.action
		if action ~= "" then
			table.insert(node_params,{action = action,child = param})
			--node_params[action] = param
		end
	end
end

local function parse_sequence(comp,node_params)
	for _,child in ipairs(comp.children) do
		local action = child.action
		if action ~= "" then
			table.insert(node_params,{action = action,child = child})
			--node_params[action] = child
		end
	end
end

local function parse_condition(comp,node_params)
	for _,child in ipairs(comp.children) do
		local action = child.action
		if action ~= "" then
			table.insert(node_params,{action = action,child = child})
			--node_params[action] = child
		end
	end
end

local function parse_script(comp,node_params)
	for _,child in ipairs(comp.children) do
		local action = child.action
		if action ~= "" then
			table.insert(node_params,{action = action,child = child})
			--node_params[action] = child
		end 
	end
end

local function parse_node(node,node_params)
	for _,comp in ipairs(node.components or {}) do
		local comp_type = comp[Def.OBJ_TYPE_MEMBER]
		if comp_type == "Component_Params" then
			parse_params(comp,node_params)
		elseif comp_type == "Component_Context" then

		elseif comp_type == "Component_Function_Param" then
		
		elseif comp_type == "Component_Sequence" then
			parse_sequence(comp,node_params)
		elseif comp_type == "Component_Condition" then
			parse_condition(comp,node_params)
		elseif comp_type == "Component_Script" then
			parse_script(comp,node_params)
		else
			assert(false, string.format("invalid commponent %s", comp_type))
		end
	end
end

local function transfrom_actions(node_params)
	for _,val in pairs(node_list) do
		parse_node(val.node,node_params)
		table.insert(node_group.actions,val.node)
	end
end

local function transfrom_export(node_params)
	local ports = {}
	local type = "ExportPort"
	local meta = Meta:meta(type)
	assert(meta, type)
	for _,val in pairs(node_list) do
		local node = val.node
		local id = node.id.value
		local is_find = false
		for _,v in ipairs(node_params) do
			if v.action == id then
				is_find = true
			end
		end
		--if not node_params[id] then
		if not is_find then
			local name = nil
			if val.type == "Action_ExecScript" then
				name = val.node.components[1].desc
			else
				name = Lang:text(val.type,true)
			end
			ports[node.pos.y] = {
				["name"] = name,
				["id"] = node.id.value,
				["type"] = node.type
			}
		end
	end
	local sort_ports = {}
	for i in pairs(ports) do
		table.insert(sort_ports,i)  
	end
	table.sort(sort_ports,
		function(a,b)
			return (tonumber(a) < tonumber(b)) 
		end
	)

	for _,v in pairs(sort_ports) do
		local val = ports[v]
		local port = meta:ctor()
		local key = port.name.value
		Lang:set_text(key,val.name)
		port.id = val.id
		port.type = val.type
		--value
		table.insert(node_group.export_node.ports,port)
	end
end

local function transfrom_import(node_params)
	local type = "ImportPort"
	local meta = Meta:meta(type)
	assert(meta,type)
	local id_mapping = {}
	for _,val in pairs(node_list) do
		local node = val["node"]
		local id = node.id.value
		id_mapping[id] = node
	end
	--for action,param in pairs(node_params) do
	for _,v in pairs(node_params) do
		local action = v.action
		local param = v.child
		if not id_mapping[action] then
			local comp_type = param[Def.OBJ_TYPE_MEMBER]
			local port = meta:ctor()
			local key = port.name.value
			if comp_type == "ActionParam" then
				Lang:set_text(key,param.key)
				port.id = param.value.action
				port.param = param
			elseif comp_type == "ScriptParam" then
				Lang:set_text(key,param.param_name)
				port.id = param.action
				port.param.value.action = param.action
			else
				Lang:set_text(key,"action_node")
				port.id = param.action
				port.param.value.action = param.action
			end
			--todo children
			table.insert(node_group.import_node.ports,port)
		end
	end	
end

local function merge_node()
	local node_params = {}
	transfrom_name()
	transfrom_pos()
	transfrom_actions(node_params)
	transfrom_export(node_params)
	transfrom_import(node_params)
	return node_group
end

return {
	init = function(nodes)
		return init(nodes)
	end,

	merge = function()
		return merge_node()
	end
}
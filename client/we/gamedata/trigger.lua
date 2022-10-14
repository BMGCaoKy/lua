local Meta = require "we.gamedata.meta.meta"
local Module = require "we.gamedata.module.module"
local VN = require "we.gamedata.vnode"
local Recorder = require "we.gamedata.recorder"

local M = {
	_run_type = "server"
}

function M:set_run_type(run_type)
	self._run_type = run_type
end

function M:get_run_type()
	return self._run_type
end

function M:list()
	local ret = {}

	local meta_set = Meta:meta_set()
	local list = meta_set:list()
	for type, meta in pairs(list) do
		if meta:specifier() == "struct" and meta:inherit("Trigger_Base") then
			table.insert(ret, {
				value = meta:name(),
				attrs = {}
			})
		end
	end

	return ret
end

function M:list_widget_trigger()
	local ret = {}
	
	local meta_set = Meta:meta_set()
	local widget_sequence = meta_set:widget_trigger_sequence()
	for type,meta in pairs(widget_sequence) do
		table.insert(ret,{
			value = meta,
			attrs = {}
		})
	end

	table.insert(ret,{
		value = "Trigger_RegisterClientProto",
		attrs = {}
	})

    table.insert(ret,{
		value = "Trigger_Custom_Client",
		attrs = {}
	})

	return ret
end

local function parse_params_component(node, id, map)
	local params = node["params"]
	if params then
		for _,param in ipairs(params) do
			local action = param["value"] and param["value"]["action"] or ""
			if action ~= "" then
				map[action] = id
			end
		end
	end
end

local function parse_sequence_component(node, id, map)
	local children = node["children"]
	if children then
		for _,child in ipairs(children) do
			local action = child["action"]
			if action ~= "" then
				map[action] = id
			end
		end
	end
end

local check_functions_mapping = {
		Action_Function = function(node, additional)
			return node["func_name"] == additional[2]
		end,
		Action_TriggerCustom = function(node, additional)
			return node["register_id"] == additional[3]
		end,
		Action_Protocol_SendToServer = function(node, additional)
			return node["components"][1]["proto_id"] == additional[3]
		end,
		Action_Protocol_SendToClient = function(node, additional)
			return node["components"][1]["proto_id"] == additional[3]
		end,
}
local parse_functions_mapping = {
	Component_Params = parse_params_component,
	Component_Sequence = parse_sequence_component,
	Component_Sequence_Bool = parse_sequence_component,
	Component_Context = function()
	end,
	Component_Condition = parse_sequence_component,
	Component_Var = function()
	end,
	Component_Script = parse_sequence_component
}

local function save_connect_info_to_map(components_node, id, map)
	for _,node in ipairs(components_node) do
		local meta = VN.meta(node)
		local name = meta:name()
		local func = parse_functions_mapping[name]
		if func then
			func(node, id, map)
		end
	end
end

--ui蓝图中的引用需求更多信息
--window_node_path
--window_path
--file_path
local function insert_window_info(node,tb)
	local temp_node = node
	local window_path = ""
	while VN.parent(temp_node) do
		if VN.meta(temp_node):inherit("Window_Base") then
			window_path = temp_node["name"] .. "/" .. window_path
		end
		temp_node = VN.parent(temp_node)
	end

	if window_path ~= "" then
		window_path = string.sub(window_path, 0, -2)
	else
		window_path = "Layout"
	end

	tb["window_path"] = window_path
	tb["file_path"] = temp_node["path"]

	local path = VN.path(node)
	local _, index = string.find(path, "triggers")
	if index then
		tb["node_path"] = string.sub(path, 0, index)
	end
end


--[[
	params:
		additional:{action_name,...}第一项为查找的action名字,后面的为查找不同节点时的附加参数
	return:
		{{module_name, item_id, trigger_name, action_id. is_link},{...}}
]]
function M:search_action_node(additional)
	local action_name = additional[1]
	local results = {}
	local connect_actions_map = {}
	local entry_id_map = {}
	for _,module in pairs(Module:list()) do
		local module_name = module:name()
		if module_name  == "blue_protocol" then
			goto continue
		end
		for _, item in pairs(module:list()) do
			local root = item:obj()
			local item_id = item:id()
			local trigger_name = ""
			local action_id = ""
			local trigger_set_name = ""
			VN.iter(root,
				function(node)
					local meta = VN.meta(node)
					--需要处理三种情况
					return (meta:name() == "Trigger") or (meta:inherit("Action_Base")) or (meta:name() == action_name) or (node["__key"] == "triggers_client") or (node["__key"] == "triggers")
				end,
				function(node)
					local meta = VN.meta(node)

					--module为game时有两个蓝图，需要做区分
					if node["__key"] == "triggers_client" or (node["__key"] == "triggers") then
						trigger_set_name = node["__key"]
					end
					--是trigger时保存root的id与item_id的映射
					if meta:name() == "Trigger" then
						trigger_name = node["type"]
						if node.func_name and node.func_name ~="" then
							trigger_name = trigger_name .. ":" ..node.func_name
						elseif node.custom_trigger_name and node.custom_trigger_name ~="" then
							trigger_name = node.custom_trigger_name
						end
						local id = node["root"]["id"]["value"]
						entry_id_map[id] = item_id
					end
					--检查是否继承于Action_Base，保存连线信息
					if meta:inherit("Action_Base") then
						local components = node["components"]
						local id = node["id"] and node["id"]["value"] or ""
						save_connect_info_to_map(node["components"], id, connect_actions_map)
					end
					--是目标节点时保存指定信息
                    if meta:name() == action_name then
						--调用针对不同节点的检查函数
						local func = check_functions_mapping[action_name]
                        if not func or func(node, additional) then
							action_id = node["id"] and node["id"]["value"] or ""
							local result = {module_name = module_name, item_id = item_id, trigger_name = trigger_name, action_id = action_id, absolute_path = VN.path(node), trigger_set_name = trigger_set_name}

							if module_name == "layout" then
								insert_window_info(node, result)
							end
							table.insert(results,result)
						end
                    end

				end
			)
		end

		::continue::
	end
	--检查是否会有机会执行到
	for _,tb in ipairs(results) do
		local id = tb["action_id"]
		--溯源
		while connect_actions_map[id] do
			id = connect_actions_map[id]
		end
		--如果能够溯源到根节点说明节点有机会执行到,追加link状态
		tb["is_link"] = entry_id_map[id] and true or false
	end
	return results
end

local function search_action_node_return_nodes(additional)
	local nodes = {}
	local action_name = additional[1]
	for _,module in pairs(Module:list()) do
		local module_name = module:name()
		if module_name  == "blue_protocol" then
			goto continue
		end
		for _, item in pairs(module:list()) do
			local root = item:obj()
			VN.iter(root,
				function(node)
					local meta = VN.meta(node)
					--需要处理三种情况
					return (meta:name() == "Trigger") or (meta:inherit("Action_Base")) or (meta:name() == action_name)
				end,
				function(node)
					local meta = VN.meta(node)
					--是目标节点时保存指定信息
                    if meta:name() == action_name then
						--调用针对不同节点的检查函数
						local func = check_functions_mapping[action_name]
                        if not func or func(node, additional) then
							table.insert(nodes,node)
						end
                    end
				end
			)
		end

		::continue::
	end
	return nodes
end

local function find_node(vnode, path)
	for name in string.gmatch(path, "[^/]+") do
		vnode = vnode[name]
		if not vnode then
			return
		end
	end

	return vnode
end

function M:sync_reference_node_value(additional,path,index,value)
	local vnodes = search_action_node_return_nodes(additional)
	local enable = Recorder:enable()
	Recorder:set_enable(false)
	for _,vnode in ipairs(vnodes) do
		local node_sync = find_node(vnode,path)

		if index == "Sync_Remove" then
			VN.remove(node_sync,tonumber(value))
		elseif index == "Sync_Move" then
		    local move_info = {}
			for name in string.gmatch(value, "[^/]+") do
				table.insert(move_info,name)
			end

			VN.move(node_sync,tonumber(move_info[1]),tonumber(move_info[2]))

		elseif index == "Sync_Insert" then
			local obj = {}
			obj["must"] = "true"
			obj["data_type"] = ""
			obj["key"] = value 
			local child_index = VN.insert(node_sync,nil,obj,nil)
			local node_param = find_node(node_sync,tostring(child_index))
			VN.assign(node_param, "data_type", "T_Int")
			--local node_child = find_node(node_sync,tostring(child_index).."/value")
			--VN.ctor(node_param,"T_Int",node_child)
		elseif index == "Sync_Delete" then
			local key = VN.key(vnode)
			local parent = VN.parent(vnode)
			VN.remove(parent,key)
		else
			VN.assign(node_sync, index, value)
		end
	end
	Recorder:set_enable(enable)
end

function M:find_custom_trigger_define(additional)
	local name = additional[1]
	local type = additional[2]
	local find = nil
	local result = {}
	for _,module in pairs(Module:list()) do
		local module_name = module:name()
		if module_name  == "blue_protocol" then
			goto continue
		end
		for _, item in pairs(module:list()) do
			local root = item:obj()
			local item_id = item:id()
			VN.iter(root,
				"Trigger",
				function(node)
                    if type == node["type"] and node.func_name == name then
						result["module_name"] = module_name 
						result["item_id"] = item_id 
						result["absolute_path"] = VN.path(node)
						find = true
					end
				end
			)
			if find then
				return result
			end
		end

		::continue::
	end
	return
end

return M

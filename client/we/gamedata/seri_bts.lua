local Def = require "we.def"
local Meta = require "we.gamedata.meta.meta"
local Converter = require "we.gamedata.export.data_converter"

local M = {}
local nodes
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
		local param_value = parse_param_value(param.value and param.value.rawval)
		if id and id ~= "" then
			action.funcs[param.key] = parse_node(id)
		else
			if param.key and param.key ~= "" then
				action.params[param.key] = param_value
			else
				table.insert(action.params,param_value)
			end
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

local function parse_comp_script(comp, action, id)
    action.funcs = {}
	for _, param in ipairs(comp.children) do
		local action_id = param.action
		local param_name = param.param_name
		if action_id and action_id ~= "" then
			action.funcs[param_name] = parse_node(action_id)
		elseif not action_id then
			action_id = param.value.action
		end
	end

    action.params = {
		script_name = comp.script_name
	}
end

local function parse_comp_proto_param(comp,action)
	assert(not action.params)

	action.params = {}
	action.params["key"] = "p_"..comp.key
end

local function parse_comp_proto(comp,action)
	assert(not action.funcs)
	assert(not action.params)

	action.funcs = {}
	action.params = {}

	local table_params = {}
	table.insert(table_params,comp.params)
	if comp.params_default then
		table.insert(table_params,comp.params_default)
	end

	for _,params in ipairs(table_params) do
		for _, param in ipairs(params) do
			local id = param.value.action
			local param_value = parse_param_value(param.value and param.value.rawval)
			if id and id ~= "" then
				local key = param.key
				if key ~= "player" then
					key = "p_"..key			
				end	
				action.funcs[key] = parse_node(id)
			else
				if param.key and param.key ~= "" then
					action.params["p_"..param.key] = param_value
				else
					table.insert(action.params,param_value)
				end
			end
		end
	end

	local name = comp.proto_type.."_"..string.gsub(comp.proto_id,"-","_")
    action.params["msg"] = name
end

parse_action = function(action)
	local ret = {}

	ret["type"] = action.name
	local action_type = action[Def.OBJ_TYPE_MEMBER]

	if action_type == "Action_SpawnItemToWorld" then
		local comp = action.components[1]
		parse_comp_params(comp, ret)
		local params_control = ret.params["params_control"]
		ret.params["params_control"] = nil
		if params_control then
			ret.params["pitch"] = nil
			ret.params["yaw"] = nil
		end
	elseif action_type == "Action_AddEntityBuff" or action_type == "Action_AddTeamBuff" then
		local comp = action.components[1]
		parse_comp_params(comp, ret)
		local limit = ret.params["limit"]
		ret.params["limit"] = nil
		if limit == false then
			ret.params["buffTime"] = nil
		end
	elseif action_type == "Action_UnaryOper_Not" then
		local comp = action.components[1]
		parse_comp_params(comp, ret)
		ret.params["op"] = "not"
	elseif action_type == "Action_ComputeString" then
		local comp = action.components[1]
		parse_comp_params(comp, ret)
		ret.params["op"] = "=="
	elseif action_type == "Action_Trigonometry" then
		local comp = action.components[1]
		parse_comp_params(comp, ret)
		ret["type"] = ret.params["operator"]
		ret.params[1] = ret.params["angle"]
		ret.params["operator"] = nil
		ret.params["angle"] = nil
	elseif action_type == "Action_SetPartShape" then
		local comp = action.components[1]
		parse_comp_params(comp, ret)
		ret.params["shapeId"] = tonumber(ret.params["shapeId"])
	elseif action_type == "Action_SetPartColor" or action_type == "Action_SetPartOperationColor" then
		local comp = action.components[1]
		parse_comp_params(comp, ret)
		local color = {
			ret.params["color"].r / 255,
			ret.params["color"].g / 255,
			ret.params["color"].b / 255,
			ret.params["color"].a / 255
		}
		ret.params["color"] = color
	elseif action_type == "Action_CreatePart" then
		local comp = action.components[1]
		parse_comp_params(comp, ret)
		local color = {
			ret.params["color"].r / 255,
			ret.params["color"].g / 255,
			ret.params["color"].b / 255,
			ret.params["color"].a / 255
		}
		ret.params["color"] = color
	else
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
			elseif comp_type == "Component_Script" then
				parse_comp_script(comp,ret)
			elseif comp_type == "Component_Proto_Params" or comp_type == "Component_Proto_Params_To_Client" then
				parse_comp_proto(comp, ret)
			elseif comp_type == "Component_Proto_Param" then
				parse_comp_proto_param(comp, ret)
			else
				assert(false, string.format("invalid commponent %s", comp_type))
			end
		end
	end
			

	return ret
end

local function parse_group_action(id,actions,port)
	for node_index,node in ipairs(actions) do
		for comp_index,comp in ipairs(node.components or {}) do
			local comp_type = comp[Def.OBJ_TYPE_MEMBER]
			if comp_type == "Component_Params" then
				for index,param in ipairs(comp.params) do
					local action = param.value.action
					if id == action then
						actions[node_index].components[comp_index].params[index] = port.param
					end
 				end
			elseif comp_type == "Component_Condition" then
				for index,child in ipairs(comp.children) do
					local action = child.action
					if id == action then
						actions[node_index].components[comp_index].children[index].action = ""
					end
				end
			elseif comp_type == "Component_Sequence" then
				for index,child in ipairs(comp.children) do
					local action = child.action
					if id == action then
						actions[node_index].components[comp_index].children[index].action = ""
					end
				end
			elseif comp_type == "Component_Context" then
						
			elseif comp_type == "Component_Function_Param" then
						
			elseif comp_type == "Component_Script" then
				for index,param in ipairs(comp.children) do
					local action = param.action
					if id == action then
						actions[node_index].components[comp_index].children[index].action = port.param.value.action
					end
 				end
			else
				assert(false, string.format("invalid commponent %s", comp_type))
			end
		end
	end
end

local function parse_group(group)
	for _,port in ipairs(group.import_node.ports) do
		local port_action = port.param.value.action
		local id = port.id
		parse_group_action(id,group.actions,port)
	end
end

local function parse_trigger(trigger)
	local ret = {}
	for _, action in ipairs(trigger.actions) do
		if action[Def.OBJ_TYPE_MEMBER] == "Node_CollapseGraph" then
			parse_group(action)
			for _, node in ipairs(action.actions) do
				nodes[node.id.value] = node
			end
		end
		nodes[action.id.value] = action
	end

	ret["type"] = function()
		if not trigger.custom then
            if trigger.type == "Function_Called" then
                return trigger.func_name
            end
			if trigger.type == "Trigger_RegisterClientProto"  then
				return "client_"..string.gsub(trigger.proto_uuid,"-","_")
			end
			if trigger.type == "Trigger_RegisterServerProto"  then
				return "server_"..string.gsub(trigger.proto_uuid,"-","_")
			end
			if trigger.type == "Trigger_RegisterServerProto"  then
				return "server_"..string.gsub(trigger.proto_uuid,"-","_")
			end
            if trigger.type == "Trigger_Custom" or trigger.type == "Trigger_Custom_Client" then
                return trigger.custom_trigger_name
            end
			local meta = Meta:meta(trigger.type)
			assert(meta, string.format("invalid type %s", trigger.type))

			local val = meta:ctor()
			return val.name
		else
			return trigger.type
		end
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

function M:transform(triggers)
	local ret = {}
	nodes = {}
	for _, trigger in ipairs(triggers.list or {}) do
		table.insert(ret, parse_trigger(trigger))
	end
	return ret
end

return M
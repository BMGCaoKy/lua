local Def = require "we.def"
local Meta = require "we.gamedata.meta.meta"
local Lang = require "we.gamedata.lang"
local lfs = require "lfs"

local copy_type = nil
local paste_type = nil
local node_list = {}

local function init(type, nodes)
	copy_type = type
	node_list = nodes
end

local function copy_types()
	local types = {}
	for _,val in pairs(node_list) do
		table.insert(types, val["type"])
	end
	return types
end

local function node_count()
	return #node_list
end

local function get_non_repetitive_name(name)
	local path = Lib.combinePath(Def.PATH_GAME,"trigger_script")
	local base_names = {}
	for file_name in lfs.dir(path) do
		local index = string.find(file_name,".lua") 
		if index == #file_name - 3 then
			local base_name = string.sub(file_name, 1, index - 1)
			base_names[base_name] = true
		end
	end

	local index = 0
	local cur_name = name
	while base_names[cur_name] do
		index = index + 1
		cur_name = string.format("%s_%d",name,index)
	end
	return cur_name
end

local function copy_script(old_file_name,new_file_name)
	local script_path = Lib.combinePath(Def.PATH_GAME,"trigger_script")
	local old_path = Lib.combinePath(script_path, old_file_name .. ".lua")
	local new_path = Lib.combinePath(script_path, new_file_name .. ".lua")
	Lib.copyFile(old_path,new_path)
end


local function parse_params(comp,id_mapping)
	for _,param in ipairs(comp.params) do
		local action = param["value"]["action"]
		local id = id_mapping[action]
		if not id then
			param["value"]["action"] = ""
		else
			param["value"]["action"] = id_mapping[action]
		end
		
		if param.value[Def.OBJ_TYPE_MEMBER] == "T_Text" then
			local id = GenUuid()
			Lang:copy_text(id,param.value.rawval.value)
			param.value.rawval.value = id
		end
	end
end

local function parse_context(comp,id_mapping,new_id)
	local sign = Lib.splitIncludeEmptyString(comp.key, "/")
	local sign_ = Lib.splitIncludeEmptyString(comp.key, "_")
	--兼容旧版的跨trigger参数(因为旧版采用/error)
	local is_loopback = string.find(comp.key,paste_type)
	--跨trigger复制，并且末尾不存在错误则不全错误
	if paste_type ~= copy_type and  sign[#sign] ~= "error" and  sign_[#sign_] ~= "error" then
		comp.key = string.format("%s.%s.name_error", copy_type, comp.key)
	--跨trigger复制，末尾存在错误，并且是从当前trigger复制出去的，将变量名从字符串中提取出来
	--默认变量名为字母数字下划线构成
	elseif paste_type ~= copy_type and is_loopback and (sign[#sign] == "error" or  sign_[#sign_] == "error") then
		local segs = Lib.splitIncludeEmptyString(comp.key, ".")
		comp.key = segs[2]
	else
		local old_id = id_mapping[new_id]
		for _,val in pairs(node_list) do
			local action = val["node"]
			if action.id.value == old_id then
				comp.key = action.components[1].key
			end
		end
	end
end

local function parse_function_param(comp,id_mapping,new_id)
	local old_id = id_mapping[new_id]
	for _,val in pairs(node_list) do
		local action = val["node"]
		if action.id.value == old_id then
			comp.key = action.components[1].key
		end
	end
end

local function parse_sequence(comp,id_mapping)
	for _,child in ipairs(comp.children) do
		local action = child.action
		local id = id_mapping[action]
		if not id then
			child.action = ""
		else
			child.action = id_mapping[action]
		end
	end
end

local function parse_condition(comp,id_mapping)
	for _,child in ipairs(comp.children) do
		local action = child.action
		local id = id_mapping[action]
		if not id then
			child.action = ""
		else
			child.action = id_mapping[action]
		end
	end
end

local function parse_script(comp,id_mapping)
	for _,child in ipairs(comp.children) do
		local action = child["action"]
		local id = id_mapping[action]
		if not id then
			child["action"] = ""
		else
			child["action"] = id_mapping[action]
		end
	end
	if comp["script_name"] ~= "" then
		local new_script_name = get_non_repetitive_name("ScriptableNode")
		copy_script(comp["script_name"],new_script_name)
		comp["script_name"] = new_script_name
	end
end

local function parse_proto(comp, id_mapping)
    for _,param in ipairs(comp.params) do
		local action = param["value"]["action"]
		local id = id_mapping[action]
		if not id then
			param["value"]["action"] = ""
		else
			param["value"]["action"] = id_mapping[action]
		end
	end

	if comp.params_default then 
		for _,param in ipairs(comp.params_default) do
			local action = param["value"]["action"]
			local id = id_mapping[action]
			if not id then
				param["value"]["action"] = ""
			else
				param["value"]["action"] = id_mapping[action]
			end
		end
	end
end

local function parse_action(action,id_mapping)
	for _,comp in ipairs(action.components or {}) do
		local comp_type = comp[Def.OBJ_TYPE_MEMBER]
		if comp_type == "Component_Params" then
			parse_params(comp,id_mapping)
		elseif comp_type == "Component_Context" then
			parse_context(comp,id_mapping,action.id.value)
		elseif comp_type == "Component_Function_Param" then
			parse_function_param(comp,id_mapping,action.id.value)
		elseif comp_type == "Component_Sequence" then
			parse_sequence(comp,id_mapping)
		elseif comp_type == "Component_Condition" then
			parse_condition(comp,id_mapping)
		elseif comp_type == "Component_Script" then
			parse_script(comp,id_mapping)
		elseif comp_type == "Component_Proto_Param" then
			parse_function_param(comp,id_mapping)
        elseif comp_type == "Component_Proto_Params" or comp_type == "Component_Proto_Params_To_Client" then
            parse_proto(comp, id_mapping)
		else
			assert(false, string.format("invalid commponent %s", comp_type))
		end
	end
end

local function parse_group_action(group,id_mapping)
	for _, node in ipairs(group.actions or {}) do
		local old_id = node.id.value
		local new_id = GenUuid()
		id_mapping[old_id] = new_id
		id_mapping[new_id] = old_id
		node.id.value = new_id
	end
end

local function parse_group(group,id_mapping)
	for _, action in ipairs(group.actions or {}) do
		parse_action(action,id_mapping)
	end

	for _,port in ipairs(group.export_node.ports) do
		local old_id = port.id
		local id = id_mapping[old_id]
		if id then
			port.id = id
		end
	end

	for _,port in ipairs(group.import_node.ports) do
		local old_id = port.param.value.action
		local id = id_mapping[old_id]
		if not id then
			port.param.value.action = ""
		else
			port.param.value.action = id
		end
	end
end

local function transfrom_pos(transfrom_nodes,pos)
	local pos_x = {}
	local pos_y = {}
	for _,val in pairs(transfrom_nodes) do
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

	for _,val in pairs(transfrom_nodes) do
		local action = val["node"]
		local vx = action.pos.x - centre_x
		local vy = action.pos.y - centre_y

		action.pos.x = pos.x + vx
		action.pos.y = pos.y + vy
	end
end

local function paste_nodes(type, pos)
	if #node_list < 1 then
		return node_list
	end
	paste_type = type
	local transfrom_nodes = Lib.copy(node_list)
	transfrom_pos(transfrom_nodes,pos)
	local tran_nodes = {}
	local tran_groups = {}
	local id_mapping = {}
	local ret = {}

	for _,val in pairs(transfrom_nodes) do
		local type = val["type"]
		local action = val["node"]
		local old_id = action["id"]["value"]
		local new_id = GenUuid()
		id_mapping[old_id] = new_id
		id_mapping[new_id] = old_id
		action["id"]["value"] = new_id
		if type == "Node_CollapseGraph" then
			parse_group_action(action,id_mapping)
			table.insert(tran_groups,val)
		else
			table.insert(tran_nodes,val)
		end
	end

	for _,val in pairs(tran_nodes) do
		local type = val["type"]
		if type == "Action_Protocol_SendToClient" then
			local node = val["node"]
			local old_id = node["components"][1]["params_default"][1]["value"]["action"]
			if old_id ~= "" then
				node["components"][1]["params_default"][1]["value"]["action"] = id_mapping[old_id]
			end
		end
		parse_action(val["node"],id_mapping)
		table.insert(ret,val)
	end

	for _,val in pairs(tran_groups) do
		parse_group(val["node"],id_mapping)
		table.insert(ret,val)
	end

	return ret
end

return {
	init = function(type, nodes)
		return init(type, nodes)
	end,

	node_count = function()
		return node_count()
	end,

	paste = function(type, pos)
		return paste_nodes(type, pos)
	end,

	copy_types = function()
		return copy_types()
	end
}
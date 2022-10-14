local Def = require "we.def"
local Map = require "we.view.scene.map"
local IWorld = require "we.engine.engine_world"
local Seri = require "we.gamedata.seri"
local Utils = require "we.view.scene.utils"
local Meta = require "we.gamedata.meta.meta"

local M = {}

local function write(file_name, data)
	local path = Lib.combinePath(Def.PATH_MERGESHAPESDATA, string.format("%s.json",file_name))
	os.remove(path)
	local file, errmsg = io.open(path, "w+b")
	assert(file, errmsg)
	file:write(Lib.toJson(data))
	file:close()
end

local function check_base(type,obj_type)
	local meta = Meta:meta(obj_type)
	return meta:inherit(type)
end

function M:create_merge_shapes_file(instances)
	Lib.mkPath(Def.PATH_MERGESHAPESDATA)

	local function get_instance(val)
		local temporary = false
		local ret = Map:query_instance(val.id)
		if ret then
			ret = ret:node()
		else
			--根据配置创建临时对象
			ret = assert(IWorld:create_instance(
				Utils.export_inst(
					val,true
				),false
			))
			temporary = true
		end
		
		return ret,temporary
	end

	local function get_children(children)
		local temporary_children = {}
		local ret = {} 
		for _, child in ipairs(children) do
			if check_base("Instance_CSGShape",child["__OBJ_TYPE"]) then
				local part, temporary = get_instance(child)
				if temporary then
					table.insert(temporary_children, part)
				end
				table.insert(ret, part)
			end
		end
		return ret, temporary_children
	end

	local function write_merge_shapes_file(instances)
		for _,val in ipairs(instances) do
			if val.class == "PartOperation" then
				local key = val.mergeShapesDataKey
				if key and key ~= "" then
					write_merge_shapes_file(val.componentList)
					local data = {}
					local part_operation, temporary = get_instance(val)
					local component_list, tmp_component = get_children(val.componentList)
					part_operation:getMergeShapesDataAsTable(component_list, data)

					if temporary then
						--销毁临时对象
						IWorld:remove_instance(part_operation)
					end
					for _,child in ipairs(tmp_component) do
						--销毁临时对象
						IWorld:remove_instance(child)
					end

					write(key, data)
				end
			end
			for _, child in ipairs(val.children) do 
				write_merge_shapes_file(child)
			end
		end
	end

	write_merge_shapes_file(instances)

end

function M:create_part_trigger_file(instances)
	for _, val in ipairs(instances) do
		local condition = val.class == "Part" and #val.triggers.list > 0
		if condition then
			local file_name = string.format("%s.bts",val.btsKey)
			local path = Lib.combinePath(Def.PATH_EVENTS, file_name)
			Seri("bts", val.triggers, path, true)
		end
	end
end

return M
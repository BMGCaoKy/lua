local Meta = require "we.gamedata.meta.meta"
local Recorder = require "we.gamedata.recorder"
local Module = require "we.gamedata.module.module"

local M = {}

function M:init(item, datas, path, index)
	self._item = item:layout_item()
	self._datas = datas or {}
	self._path = path
	self._path_child_name = {}
	if index == -1 then
		self._index = nil
	end

	local register_obj_trigger_proto
	register_obj_trigger_proto = function(obj)
		if obj["triggers"] then
			local triggers = obj["triggers"]["list"]
			for key,v in pairs(triggers) do
				if v.type == "Trigger_RegisterClientProto" or v.type == "Trigger_RegisterServerProto"  then
					local id = v.proto_uuid
					local module = Module:module("blue_protocol")
					local id_new = GenUuid()
					local item_new = module:copy_item(id,id_new)
					item_new:obj().save = true
					obj["triggers"]["list"][key].proto_uuid = id_new
					obj["triggers"]["list"][key].func_name = item_new:obj().name
				end
			end
		end
		for _,child in pairs(obj["children"]) do
			register_obj_trigger_proto(child)
		end
    end

	local trans_obj
	trans_obj = function(obj)
		obj["id"]["value"] = GenUuid()
		for _,child in pairs(obj["children"]) do
			trans_obj(child)
		end
	end
	self.copy_infos = {}
	for k,v in ipairs(self._datas) do
		local copy_info = {}
		copy_info._type = v.gui_type
		copy_info._data = Lib.copy(v)
		copy_info._data.id.value = GenUuid()
		trans_obj(copy_info._data)
		register_obj_trigger_proto(copy_info._data)
		local meta = Meta:meta(copy_info._type)
		copy_info._data.name = self:MultipleNameDetection(path, copy_info._data.name)--TODO  自定义的名称复制后被覆盖
		table.insert(self.copy_infos,copy_info)
	end
	self:recorder()
end

function M:recorder()
	if self.copy_infos == {} then 
		return
	end
	Recorder:start()
	for k,v in pairs(self.copy_infos) do
		self._item:data():insert(self._path, nil, v._type, v._data)
	end
	Recorder:stop()
end

--重名检测,多选粘贴时存在多个未插入的同名节点
--layout的verify_window_name只能在当前已存在的name中检测
function M:MultipleNameDetection(path, def_name)
	if not self._path_child_name[path] then
		local item_obj = self._item:obj()
		for name in string.gmatch(path, "[^/]+") do
			item_obj = item_obj[name]
		end
		local name_table = {}
		for _,child in pairs(item_obj) do
			table.insert(name_table,child.name)
		end
		self._path_child_name[path] = name_table
	end

	local name = def_name
	local get_name
	get_name = function(def,index)
		for _,v in pairs(self._path_child_name[path]) do
			while true do
				if def == v then
					index = index + 1
					def = name..index
					return get_name(def,index)
				end
				break
			end
		end
		table.insert(self._path_child_name[path],def)
		return def
	end
	
	return get_name(def_name,0)
end

return M
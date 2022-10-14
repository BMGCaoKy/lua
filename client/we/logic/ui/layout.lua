local guiMgr = GUIManager:Instance()
local Module = require "we.gamedata.module.module"
local Signal = require "we.signal"
local Def = require "we.def"
local Window = require "we.logic.ui.window"
local VN = require "we.gamedata.vnode"
local Recorder = require "we.gamedata.recorder"
local Lang = require "we.gamedata.lang"

local layout_class = {}

function layout_class:init(path, id)
	local module = Module:module("layout")
	self._layout_item = module:item(id)
	assert(self._layout_item,id)
	--self._window = assert(UI:openCustomWindow(layout), layout)
	assert(string.sub(path, -7)== ".layout")
	local trans_path = string.sub(path,#Def.PATH_GAME_ASSET + 1, -8)
	local ok,index = string.find(path,"asset/")
	if index then
		self._window = assert(UI:openWindow(trans_path), trans_path)
	else
		-- 预设界面
		trans_path = string.sub(path,#Def.PATH_UI_CUSTOM_LAYOUT + 1, -8)
		self._window = assert(UI:openWindow(trans_path,nil,"_layouts_"), trans_path)
	end
	

	local Recorder = require "we.gamedata.recorder"
	local enable = Recorder:enable()
	Recorder:set_enable(false)
	do
		local root = self._layout_item:obj()["root"]
		self.root_window = Lib.derive(Window)
		self.root_window:init(root,self._window,false)
	end
	Recorder:set_enable(enable)
	self._window:hide()
	Lang:save()
	self._layout_item:save()
end

function layout_class:update_window()
	self.root_window:update_window()
end

function layout_class:layout_item()
	return self._layout_item
end

function layout_class:layout_item_root()
	return self._layout_item:obj()["root"]
end

function layout_class:layout_window()
	return self._window
end

function layout_class:show_window()
	if self:layout_item_root()["Visible"] then
		self._window:show()
	end
end

function layout_class:hide_window()
	self._window:hide()
end

function layout_class:close_window()
	UI:closeWindow(self._window)
	self._window = nil
end

--guiWindow ʵʱ·��
function layout_class:window_path()
	local path_table = {}
	local root = self:layout_item():obj()["root"]
	local children = root["children"]
	local get_path
	get_path = function(path_table,children,path)
		for _,child in pairs(children) do
			--(a and {b} or {c})[1]
			local self_path = (path and {path..'/'..child.name} or {child.name})[1]
			path_table[child.id.value] = self_path
			get_path(path_table,child.children,self_path)
		end
	end
	get_path(path_table,children)

	return path_table
end

function layout_class:get_window(id)
	local root = self:layout_item_root()
	if id == root.id.value then
		return self._window
	end
	local path = self:window_path()[id]
	if path and self._window:isChildName(path) then
		return self._window:getChildByName(path)
	end
end

function layout_class:copy_window(paths)
	local duplicate_removal
	--如果节点的父节点会被复制，则取消复制该节点
	local duplicate_removal = function (paths)
		local copy_paths = {}
		for _,path in pairs(paths) do
			local not_copy = false
			for _,contrast in pairs(paths) do
				if string.find(path["path"], contrast["path"]) and path["path"] ~= contrast["path"] then
					not_copy = true
				end
			end
			if not not_copy then
				table.insert(copy_paths, path)
			end
		end
		return copy_paths
	end

	local trans_obj
	trans_obj = function(obj)
		obj["id"]["value"] = GenUuid()
		if obj["text_key"] then
			local text_key = obj["text_key"].value
			local new_text_key = text_key.."#copy_temp"
			Lang:copy_text_to_temp_text(text_key,new_text_key)
			obj["text_key"].value = new_text_key
		end
		for _,child in pairs(obj["children"]) do
			trans_obj(child)
		end
	end

	self._copy_datas = {}
	local copy_paths = duplicate_removal(paths)
	for k,v in pairs(copy_paths) do
		local path = v["path"]
		local item_obj = self._layout_item:obj()
		for name in string.gmatch(path, "[^/]+") do
			item_obj = item_obj[name]
		end
		local copy_data = Lib.copy(item_obj)

		trans_obj(copy_data)
		table.insert(self._copy_datas, copy_data)
	end
end

function layout_class:copy_datas()
	return self._copy_datas
end

function layout_class:copy_count()
	if not self._copy_datas then
		return 0
	end
	return #self._copy_datas
end

function layout_class:delete_window(id)
	local root = self:layout_item_root()
	local del
	del = function(item,id)
		local children = item["children"]
		for index,child in ipairs(children) do
			local child_id = child["id"]["value"]
			if child_id == id then
				VN.remove(children,index)
			else
				del(child,id)
			end
		end
	end
	del(root,id)
end

--根据指定路径检测重名
function layout_class:verify_window_name(path,def_name)
	local item_obj = self._layout_item:obj()
	for name in string.gmatch(path, "[^/]+") do
		item_obj = item_obj[name]
	end
	local name_table = {}
	for _,child in pairs(item_obj) do
		table.insert(name_table,child.name)
	end

	local name = self:verify_window_name2(name_table,def_name)
	return name
end

--根据名字列表检测重名
function layout_class:verify_window_name2(name_table,def_name)
	local name = def_name
	local get_name
	get_name = function(def,index)
		for _,v in pairs(name_table) do
			while true do
				if def == v then
					index = index + 1
					def = name..index
					return get_name(def,index)
				end
				break
			end
		end
		return def
	end
	return get_name(def_name,0)
end

-- 多选时候处理坐标转换
function layout_class:conversion_udim_by_paths(items_path,path)
	if not items_path then
		return
	end

	Recorder:start()
	for _,item_path in ipairs(items_path) do
		local path_new = item_path.."/"..path
		self:conversion_udim_by_path(path_new)
	end
	Recorder:stop()
end

function layout_class:conversion_udim_by_path(path)
	--找出转化的目标控件
	local item_obj = self._layout_item:obj()
	local window = self.root_window
	for name in string.gmatch(path, "[^/]+") do
		local obj = item_obj[name]
		if type(obj) == "table" and obj.id and window then
			local id = obj.id.value
			--root 就是第一个window
			if name ~= "root" then
				window = window:window_child()[id]
			end
		end
		item_obj = obj
	end
	if not window then
		return
	end
	--root/children/1/children/1/children/1/pos/UDim_X/Scale
	--root/children/1/children/1/children/1/size/UDim_Y/Offect
	--找出转化方向
	local strs = Lib.splitString(path, "/")
	local transform_type = strs[#strs - 2]
	local transform_dir = strs[#strs - 1]
	local conversion_dir = strs[#strs]

	window:conversion_udim_by_dir(transform_type, transform_dir, conversion_dir)
end

return layout_class
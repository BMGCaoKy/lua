local VN = require "we.gamedata.vnode"
local Recorder = require "we.gamedata.recorder"
local UIRequest = require "we.proto.request_ui"

local M = {}

function M:init(item, target_path, item_path_list, target_index)
	self._item = item
	self._layout_item = item:layout_item()
	
	--target
	local target_obj = item:layout_item():obj()
	for name in string.gmatch(target_path,"[^/]+") do
		target_obj = target_obj[name]
	end
	--item list
	local current_item_table = {}
	local current_item_id_table = {}
	local transform_path = string.format("%s/children",target_path)
	for _,item_path in ipairs(item_path_list) do
		local item_obj = item:layout_item():obj()
		for name in string.gmatch(item_path,"[^/]+") do
			item_obj = item_obj[name]
		end

		--如果父节点在列表中，则取消子结点的拖动
		local need_move = true
		for _,path in ipairs(item_path_list) do
			local _,index = string.find(item_path,path)
			if index and index ~= #item_path then
				need_move = false
			end
		end
		if need_move then
			local id = item_obj["id"]["value"]
			table.insert(current_item_id_table,id)
			table.insert(current_item_table,item_obj)			
		end
	end

	Recorder:start()

	--当前所选中的item重名处理
	local current_item_name_table = {}
	local transform_current_item_table = {}
	for _,cur_item in ipairs(current_item_table) do
		local name = cur_item["name"]
		local transform_name = item:verify_window_name2(current_item_name_table,name)
		table.insert(current_item_name_table,transform_name)
		local transform_item = Lib.copy(cur_item)
		transform_item["name"] = transform_name
		table.insert(transform_current_item_table,transform_item)
	end

	--筛选出目标节点的子结点
	local current_item_index_table = {}
	local target_obj_children = target_obj["children"]
	for index,child in ipairs(target_obj_children) do
		local child_id = child["id"]["value"]
		for _,id in ipairs(current_item_id_table) do
			if child_id == id then
				table.insert(current_item_index_table,index)
			end
		end
	end
	--升序
	table.sort(current_item_index_table,function(a,b)
		return a < b
	end)
	if #current_item_index_table > 0 then
		local min_index = current_item_index_table[1]
		if min_index < target_index then
			local min_table = {}
			for _,index in ipairs(current_item_index_table) do
				if index < target_index then
					table.insert(min_table,index)
				end
			end
			target_index = target_index - #min_table
		end
	end
	--删除所选item，(如果所选的item已被父节点删除也没关系)
	for _,id in ipairs(current_item_id_table) do
		self._item:delete_window(id)
	end

	--目标项item名字列表
	local target_name_table = {}
	for _,child in ipairs(target_obj["children"]) do
		table.insert(target_name_table,child.name)
	end
	--和目标项已有的item重名处理
	for _,current_item in ipairs(transform_current_item_table) do
		local name = current_item["name"]
		local transform_name = item:verify_window_name2(target_name_table,name)
		current_item["name"] = transform_name
	end
	--和重名处理后的目标项item名字再次转换
	local transform_name_table = {}
	for _,current_item in ipairs(transform_current_item_table) do
		local name = current_item["name"]
		local transform_name = item:verify_window_name2(transform_name_table,name)
		table.insert(transform_name_table,transform_name)
		current_item["name"] = transform_name
	end

	--往目标项插入当前所选item
	print("target_index--------->>",target_index)
	for index,item in ipairs(transform_current_item_table) do
		local idx = target_index + (index - 1)
		local type = item.gui_type
		VN.insert(target_obj["children"], idx, item, type)
	end
	Recorder:stop()
	UIRequest.request_add_widgets(current_item_id_table)
end

return M
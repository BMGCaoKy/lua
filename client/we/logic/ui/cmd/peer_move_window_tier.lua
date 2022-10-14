local Recorder = require "we.gamedata.recorder"
local UIRequest = require "we.proto.request_ui"

local M = {}

function M:init(item, target_path, item_path_list, index)
	local target_path = string.format("%s/children",target_path)
	local layout_item = item:layout_item()
	local current_item_table = {}
	local current_item_id_table = {}
	for _,item_path in ipairs(item_path_list) do
		local item_table = {}
		local item_obj = item:layout_item():obj()
		for name in string.gmatch(item_path,"[^/]+") do
			item_obj = item_obj[name]
			table.insert(item_table,name)
		end
		local item_index = tonumber(item_table[#item_table])
		table.insert(current_item_table,{
			item_index_ = item_index,
			item_obj_ = item_obj
		})
		local id = item_obj.id.value
		table.insert(current_item_id_table,id)
	end
	--降序
	local desc_item_table = Lib.copy(current_item_table)
	table.sort(desc_item_table,function(a, b)
		local a_index = a.item_index_
		local b_index = b.item_index_
		return a_index > b_index
	end)
	--升序
	local ascend_item_table = Lib.copy(current_item_table)
	table.sort(ascend_item_table,function(a,b)
		local a_index = a.item_index_
		local b_index = b.item_index_
		return a_index < b_index
	end)

	local items_length = #desc_item_table
	local min_index = desc_item_table[items_length].item_index_
	local insert_item_table = {}
	--{1,2,3,4} {1,4} -> 2(3) {2,1,4,3}  index = 3 - 1
	--{1,2,3,4} {1,2,4} -> 3(4) {3,1,2,4} index = 4 - 2
	--从上向下拖动index = (index - 小于index的item下标中的最大下标)
	if min_index < index then
		local min_table = {}
		for _,item in ipairs(ascend_item_table) do
			local item_index = item.item_index_
			if item_index < index then
				table.insert(min_table,item_index)
			end
		end
		index = index - #min_table
	end

	for i, item in ipairs(ascend_item_table) do
		local transfrom_index = index + i - 1
		local item_obj = item.item_obj_
		if transfrom_index <= 0 then
			return
		end
		table.insert(insert_item_table,{
			index = transfrom_index,
			obj = item_obj
		})
	end

	Recorder:start()
	for _,item in ipairs(desc_item_table) do
		local item_index = item.item_index_
		layout_item:data():remove(target_path,item_index)
	end
	for _,item in ipairs(insert_item_table) do
		local index = item.index
		local obj = item.obj
		layout_item:data():insert(target_path,index,obj["gui_type"],obj)
	end
	Recorder:stop()
	UIRequest.request_add_widgets(current_item_id_table)
end

return M
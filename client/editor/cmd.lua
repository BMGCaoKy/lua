local op = require "editor.undo"

local M = {}

local function new_cmd(name, ...)
	local class = require(string.format("%s.cmd_%s", "editor.cmds", name))
	assert(class, string.format("class %s is not exist", name))

	local obj = Lib.derive(class)
	obj:init(...)

	return obj
end

function M:redo()
	if op:can_redo() then
		op:redo()
	end
end

function M:undo()
	if op:can_undo() then
		op:undo()
	end
end

function M:set_block(pos, id,b,cfg)
	local cmd = new_cmd("block_set", pos, id,b,cfg)
	op:push(cmd)
end

function M:move_block(pos_s, pos_d)
	local cmd = new_cmd("block_move", pos_s, pos_d)
	op:push(cmd)
end

function M:del_block(pos)
	local cmd = new_cmd("block_del", pos)
	op:push(cmd)
end

function M:set_chunk(pos,side, chunk)
	local cmd = new_cmd("chunk_set", pos,side, chunk)
	op:push(cmd)
end

function M:move_chunk(pos_s, pos_d, chunk)
	local cmd = new_cmd("chunk_move", pos_s, pos_d, chunk)
	op:push(cmd)
end

function M:del_chunk(pos, chunk, is_scale)
	local cmd = new_cmd("chunk_del", pos, chunk, is_scale)
	op:push(cmd)
end

function M:fill_chunk(pos, chunk, tid)
	local cmd = new_cmd("chunk_fill", pos, chunk, tid)
	op:push(cmd)
end

function M:add_region(pos)
	local cmd = new_cmd("region_set",pos)
	op:push(cmd)
end

function M:del_region(id)
	local cmd = new_cmd("region_del",id)
	op:push(cmd)
end

function M:move_region(name,obj,isupdate)
	local cmd = new_cmd("region_move",name,obj,isupdate)
	op:push(cmd)
end

function M:set_entity(pos, _table)
	local cmd = new_cmd("entity_set",pos, _table)
	return op:push(cmd)
end

function M:move_entity(id,old_data,new_data,isupdate)
	local cmd = new_cmd("entity_move",id,old_data,new_data,isupdate)
	op:push(cmd)
end

function M:del_entity(id)
	local cmd = new_cmd("entity_del",id)
	op:push(cmd)
end

function M:replace(pos_min, pos_max, rule)
	local cmd = new_cmd("replace", pos_min, pos_max, rule)
	op:push(cmd)
end

function M:replace_2(pos_min, pos_max, rule)
	local cmd = new_cmd("replace_2", pos_min, pos_max, rule)
	op:push(cmd)
end

function M:block_fill(focus_obj)
	local cmd = new_cmd("block_fill",focus_obj)
	op:push(cmd)
end

function M:set_item(pos, cfg, blockID)
	local cmd = new_cmd("item_set", pos, cfg, blockID)
	op:push(cmd)
end

function M:del_item(id, item)
	local cmd = new_cmd("item_del",id, item)
	op:push(cmd)
end

return M

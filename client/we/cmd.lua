local M = {}

local function new_cmd(name, ...)
	local class = require(string.format("%s.cmd_%s", "we.cmds", name))
	assert(class, string.format("class %s is not exist", name))

	local obj = Lib.derive(class)
	obj:init(...)

	return obj
end

local function op_stack()
	local Map = require "we.map"

	local map = Map:curr_map()
	assert(map)

	return map:op_stack()
	--[[
	local op = require "we.undo"
	return op
	]]
end

--[[
function M:redo()
	local op = op_stack()
	if not op then
		return
	end

	if op:can_redo() then
		op:redo()
	end
end

function M:undo()
	local op = op_stack()
	if not op then
		return
	end

	if op:can_undo() then
		op:undo()
	end
end
]]
function M:set_block(pos, id,b)
	local op = assert(op_stack())
	local cmd = new_cmd("block_set", pos, id,b)
	op:push(cmd)
end

function M:move_block(pos_s, pos_d)
	local op = assert(op_stack())
	local cmd = new_cmd("block_move", pos_s, pos_d)
	op:push(cmd)
end

function M:del_block(pos)
	local op = assert(op_stack())
	local cmd = new_cmd("block_del", pos)
	op:push(cmd)
end

function M:set_chunk(pos,side, chunk)
	local op = assert(op_stack())
	local cmd = new_cmd("chunk_set", pos,side, chunk)
	op:push(cmd)
end

function M:move_chunk(pos_s, pos_d, chunk)
	local op = assert(op_stack())
	local cmd = new_cmd("chunk_move", pos_s, pos_d, chunk)
	op:push(cmd)
end

function M:del_chunk(pos, chunk, is_scale)
	local op = assert(op_stack())
	local cmd = new_cmd("chunk_delete", pos, chunk, is_scale)
	op:push(cmd)
end

function M:fill_chunk(pos, chunk, tid)
	local op = assert(op_stack())
	local cmd = new_cmd("chunk_fill", pos, chunk, tid)
	op:push(cmd)
end

function M:add_region(min, max, cfg)
	local op = assert(op_stack())
	local cmd = new_cmd("region_set", min, max, cfg)
	op:push(cmd)
end

function M:del_region(id)
	local op = assert(op_stack())
	local cmd = new_cmd("region_del",id)
	op:push(cmd)
end

function M:move_region(name,obj,isupdate)
	local op = assert(op_stack())
	local cmd = new_cmd("region_move",name,obj,isupdate)
	op:push(cmd)
end

function M:set_entity(pos,cfg,yaw)
	local op = assert(op_stack())
	local cmd = new_cmd("entity_set",pos,cfg,yaw)
	op:push(cmd)
end

function M:move_entity(id,old_data,new_data,isupdate)
	local op = assert(op_stack())
	local cmd = new_cmd("entity_move",id,old_data,new_data,isupdate)
	op:push(cmd)
end

function M:del_entity(id)
	local op = assert(op_stack())
	local cmd = new_cmd("entity_del",id)
	op:push(cmd)
end

function M:replace(pos_min, pos_max, rule)
	local op = assert(op_stack())
	local cmd = new_cmd("replace", pos_min, pos_max, rule)
	op:push(cmd)
end

function M:block_fill(focus_obj)
	local op = assert(op_stack())
	local cmd = new_cmd("block_fill",focus_obj)
	op:push(cmd)
end

return M

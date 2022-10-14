local Map = require "we.view.scene.map"

local M = {}

local function cmd_stack()
	local map = Map:curr()
	assert(map)

	return map:stack()
end

local function new_cmd(name, ...)
	local class = require(string.format("%s.cmd_%s", "we.view.scene.cmd", name))
	assert(class, string.format("class %s is not exist", name))

	local obj = Lib.derive(class)
	obj:init(...)

	return obj
end

function M:block_set(list)
	local stack = cmd_stack()
	local cmd = new_cmd("block_set", list)
	stack:push(cmd, true)
end

function M:block_move(list, offset)
	local stack = cmd_stack()
	local cmd = new_cmd("block_move", list, offset)
	stack:push(cmd, true)
end

function M:block_cut(pos, id)
	local stack = cmd_stack()
	local cmd = new_cmd("block_cut", pos, id)
	stack:push(cmd, true)
end

function M:block_copy(pos, id)
	local stack = cmd_stack()
	local cmd = new_cmd("block_copy", pos, id)
	stack:push(cmd, true)
end

function M:block_dele(list)
	local stack = cmd_stack()
	local cmd = new_cmd("block_delete", list)
	stack:push(cmd, true)
end

function M:block_fill(list)
	local stack = cmd_stack()
	local cmd = new_cmd("block_fill", list)
	stack:push(cmd, true)
end

function M:chunk_move(pos, size, offset)
	local stack = cmd_stack()
	local cmd = new_cmd("chunk_move", pos, size, offset)
	stack:push(cmd, true)
end

function M:chunk_set(pos, chunk)
	local stack = cmd_stack()
	local cmd = new_cmd("chunk_set", pos, chunk)
	stack:push(cmd, true)
end

function M:chunk_replace(pos_min, pos_max, rule)
	local stack = cmd_stack()
	local cmd = new_cmd("chunk_replace", pos_min, pos_max, rule)
	stack:push(cmd, true)
end

function M:chunk_copy(pos_min, pos_max, rule)
	local stack = cmd_stack()
	local cmd = new_cmd("chunk_copy", pos_min, pos_max, rule)
	stack:push(cmd, true)
end

function M:chunk_cut(pos_min, pos_max, rule)
	local stack = cmd_stack()
	local cmd = new_cmd("chunk_cut", pos_min, pos_max, rule)
	stack:push(cmd, true)
end

function M:chunk_fill(pos, chunk, block_name)
	local stack = cmd_stack()
	local cmd = new_cmd("chunk_fill", pos, chunk, block_name)
	stack:push(cmd, true)
end

function M:chunk_dele(pos, chunk) 
	local stack = cmd_stack()
	local cmd = new_cmd("chunk_delete", pos, chunk)
	stack:push(cmd, true)
end

function M:uni_cmd(uid)
	local stack = cmd_stack()
	local cmd = new_cmd("uni_adapter", uid)
	stack:push(cmd, false)
end

return M

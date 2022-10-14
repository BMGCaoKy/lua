local M = {}

local VN
local macro_class
local cmd_op_macro

function M:init()
	VN = require "we.gamedata.vnode"
	self._enable = true
	self._macro = nil
	self._stack = nil
	self._count = 0
end

function M:set_enable(val)
	self._enable = val
end

function M:enable()
	return self._enable
end

function M:start()
	if not self._enable then
		return
	end
	if not self._macro then
		self._macro = Lib.derive(macro_class)
		self._macro:init()
	end
	--print("############# start",self._count)
	self._count = self._count + 1
end

function M:stop()
	if not self._enable then
		return
	end
	self._count = self._count - 1
	assert(self._count >= 0)
	assert(self._macro)
	--print("############# stop",self._count)
	if self._count > 0 then
		return
	end

	if self._macro:op_count() > 0 then
		local cmd = Lib.derive(cmd_op_macro)
		cmd:init(self._macro)
		self._stack:push(cmd)
	end

	self._macro = nil
	self._stack = nil
	self._trace = nil
end

function M:working()
	return self._count > 0
end

function M:count()
	return self._count
end

function M:check_stack(node, index)
	if not self._enable then
		return false
	end

	local stack, branch = VN.undo_stack(node, index)
	if not branch then
		return false
	end

	if not self._stack then
		self._stack = stack
		self._trace = debug.traceback(string.format("record from %s[%s]", VN.path(node), index))
		--print("#############not self._stack  ",VN.path(node),index,stack)
	else
		if  self._stack ~= stack then
			print("#############error assert ",VN.path(node),index,stack)
		end
		assert(self._stack == stack, self._trace)
	end

	return branch
end

function M:on_ctor(node, index, o_child, cbs)
	local branch = self:check_stack(node, index)
	if not branch then
		return
	end
	
	if not self._macro then
		print("warring: modify data out of control", debug.traceback())
		return
	end
	
	self._macro:on_ctor(branch, VN.path(node, branch), index, o_child, (node[index]), cbs)
end

function M:on_assign(node, index, oval, cbs)
	local branch = self:check_stack(node, index)
	if not branch then
		return
	end

	if not self._macro then
		print("warring: modify data out of control", debug.traceback())
		return
	end

	self._macro:on_assign(branch, VN.path(node, branch), index, oval, Lib.copy(node[index]), cbs)
end

function M:on_insert(node, index, cbs)
	local branch = self:check_stack(node)
	if not branch then
		return
	end

	if not self._macro then
		print("warring: modify data out of control", debug.traceback())
		return
	end

	self._macro:on_insert(branch, VN.path(node, branch), index, Lib.copy(node[index]), cbs)
end

function M:on_remove(node, index, oval, cbs)
	local branch = self:check_stack(node)
	if not branch then
		return
	end

	if not self._macro then
		print("warring: modify data out of control", debug.traceback())
		return
	end

	self._macro:on_remove(branch, VN.path(node, branch), index, oval, cbs)
end

function M:on_move(node, from, to, cbs)
	local branch = self:check_stack(node)
	if not branch then
		return
	end

	if not self._macro then
		print("warring: modify data out of control", debug.traceback())
		return
	end

	self._macro:on_move(branch, VN.path(node, branch), from, to, cbs)
end

function M:on_attr_change(node, index, key, oval, nval, cbs)
	local branch = self:check_stack(node)
	if not branch then
		return
	end

	self._macro:on_attr_change(branch, VN.path(node, branch), index, key, oval, nval, cbs)
end

------------------------------------------------------------
local op_base = {
	init = function(self, branch, path, cbs)
		self._undo = false
		self._branch = assert(branch)
		self._path = path
		self._cbs = cbs
	end,

	node = function(self)
		local node = self._branch
		for name in string.gmatch(self._path, "[^/]+") do
			node = node[name]
		end

		return node
	end,

	undo = function(self)
		assert(not self._undo)
		self._undo = true
	end,

	redo = function(self)
		assert(self._undo)
		self._undo = false
	end,

	combine = function(self, op)
		return false
	end
}

local op_ctor = Lib.derive(op_base, {
	init = function(self, branch, path, index, o_child, n_child, cbs)
		op_base.init(self, branch, path, cbs)

		self._index = index
		self._o_child = o_child
		self._n_child = n_child
	end,

	undo = function(self)
		op_base.undo(self)

		VN.ctor(self:node(), self._index, self._o_child, self._cbs & ~VN.CTRL_BIT.RECORDE)
	end,

	redo = function(self)
		op_base.redo(self)

		VN.ctor(self:node(), self._index, self._n_child, self._cbs & ~VN.CTRL_BIT.RECORDE)
	end
})

local op_assign = Lib.derive(op_base, {
	init = function(self, branch, path, index, oval, nval, cbs)
		op_base.init(self, branch, path, cbs)

		self._index = index
		self._oval = oval
		self._nval = nval
	end,

	undo = function(self)
		op_base.undo(self)
		VN.assign(self:node(), self._index, self._oval, self._cbs & ~VN.CTRL_BIT.RECORDE)
	end,

	redo = function(self)
		op_base.redo(self)

		VN.assign(self:node(), self._index, self._nval, self._cbs & ~VN.CTRL_BIT.RECORDE)
	end,

	combine = function(self, op)
		if op._branch ~= self._branch then
			return false
		end
		if op._path ~= self._path then
			return false
		end

		if op._index ~= self._index then
			return false
		end

		self._nval = op._nval

		return true
	end
})

local op_insert = Lib.derive(op_base, {
	init = function(self, branch, path, index, val, cbs)
		op_base.init(self, branch, path, cbs)

		self._index = index
		self._val = val
	end,

	undo = function(self)
		op_base.undo(self)
		VN.remove(self:node(), self._index, self._cbs & ~VN.CTRL_BIT.RECORDE)
	end,

	redo = function(self)
		op_base.redo(self)

		VN.insert(self:node(), self._index, self._val, nil, self._cbs & ~VN.CTRL_BIT.RECORDE)
	end
})

local op_remove = Lib.derive(op_base, {
	init = function(self, branch, path, index, oval, cbs)
		op_base.init(self, branch, path, cbs)

		self._index = index
		self._oval = oval
	end,

	undo = function(self)
		op_base.undo(self)

		VN.insert(self:node(), self._index, self._oval, nil, self._cbs & ~VN.CTRL_BIT.RECORDE)
	end,

	redo = function(self)
		op_base.redo(self)

		VN.remove(self:node(), self._index, self._cbs & ~VN.CTRL_BIT.RECORDE)
	end,
})

local op_move = Lib.derive(op_base, {
	init = function(self, branch, path, from, to, cbs)
		op_base.init(self, branch, path, cbs)

		self._from = from
		self._to = to
	end,

	undo = function(self)
		op_base.undo(self)

		VN.move(self:node(), self._to, self._from, self._cbs & ~VN.CTRL_BIT.RECORDE)
	end,

	redo = function(self)
		op_base.redo(self)

		VN.move(self:node(), self._from, self._to, self._cbs & ~VN.CTRL_BIT.RECORDE)
	end
})

local op_set_attr = Lib.derive(op_base, {
	init = function(self, branch, path, index, key, oval, nval, cbs)
		op_base.init(self, branch, path, cbs)

		self._index = index
		self._key = key
		self._oval = oval
		self._nval = nval
	end,

	undo = function(self)
		op_base.undo(self)

		VN.set_attr(self:node(), self._index, self._key, self._oval)
	end,

	redo = function(self)
		op_base.redo(self)
		
		VN.set_attr(self:node(), self._index, self._key, self._nval)
	end
})

macro_class = {
	init = function(self)
		self._ops = {}
	end,

	undo = function(self)
		for i = #self._ops, 1, -1 do
			self._ops[i]:undo()
		end
	end,

	redo = function(self)
		for i = 1, #self._ops do
			self._ops[i]:redo()
		end
	end, 

	on_ctor = function(self, branch, path, index, o_child, n_child, cbs)
		local op = Lib.derive(op_ctor)
		op:init(branch, path, index, o_child, n_child, cbs)

		table.insert(self._ops, op)
	end,

	on_assign = function(self, branch, path, index, oval, nval, cbs)
		local op = Lib.derive(op_assign)
		op:init(branch, path, index, oval, nval, cbs)
		if #self._ops <= 4 then	-- 经验值，对于一次操作改变太多数据往往不能合并，它们是操作不同的对象
			for _, v in ipairs(self._ops) do
				if v:combine(op) then
					return
				end
			end
		end
		table.insert(self._ops, op)
	end,

	on_insert = function(self, branch, path, index, val, cbs)
		local op = Lib.derive(op_insert)
		op:init(branch, path, index, val, cbs)

		table.insert(self._ops, op)
	end,

	on_remove = function(self, branch, path, index, oval, cbs)
		local op = Lib.derive(op_remove)
		op:init(branch, path, index, oval, cbs)

		table.insert(self._ops, op)
	end,

	on_move = function(self, branch, path, from, to, cbs)
		local op = Lib.derive(op_move)
		op:init(branch, path, from, to, cbs)

		table.insert(self._ops, op)
	end,

	on_attr_change = function(self, branch, path, index, key, oval, nval, cbs)
		local op = Lib.derive(op_set_attr)
		op:init(branch, path, index, key, oval, nval, cbs)

		table.insert(self._ops, op)
	end,

	op_count = function(self)
		return #self._ops
	end
}

local BaseCmd = require "we.cmd.cmd_base"
cmd_op_macro = Lib.derive(BaseCmd, {
	init = function(self, macro)
		BaseCmd.init(self)

		self._macro = assert(macro)
	end,

	redo = function(self)
		BaseCmd.redo(self)

		M:set_enable(false)
		self._macro:redo()
		M:set_enable(true)
	end,

	undo = function(self)
		BaseCmd.undo(self)

		M:set_enable(false)
		self._macro:undo()
		M:set_enable(true)
	end
})

return M

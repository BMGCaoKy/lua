local Cjson = require "cjson"
local Core = require "editor.core"
local Def = require "we.def"
local Signal = require "we.signal"
local VN = require "we.gamedata.vnode"
local Meta = require "we.gamedata.meta.meta"
local Log = require "we.log"
local Misc = require "misc"

local M = {}

local log_enabled = false

local tree_class = {
	ON_NODE_CTOR	= "ON_NODE_CTOR",
	ON_NODE_ASSIGN	= "ON_NODE_ASSIGN",
	ON_NODE_INSERT	= "ON_NODE_INSERT",
	ON_NODE_REMOVE	= "ON_NODE_REMOVE",
	ON_NODE_MOVE	= "ON_NODE_MOVE",
	ON_NODE_ATTR_CHANGED = "ON_NODE_ATTR_CHANGED",

	init = function(self, id, rawval, type)
		self._id = assert(id)
		self._type = type
		self._rawval = assert(rawval)
		self._root = nil
	end,

	id = function(self)
		return self._id
	end,

	root = function(self)
		if not self._root then
			assert(self._rawval, self._id)
			if type(self._rawval) == "function" then
				self._rawval = assert(self._rawval())
			end
			Log("New vtree begin", self._type)
			local root = VN.new(self._type, self._rawval, self)
			Log("New vtree end", self._type)
			self._root = root
			self._rawval = nil
		end
		
		return assert(self._root)
	end,

	value = function(self)
		if self._rawval then
			if type(self._rawval) == "function" then
				self._rawval = self._rawval()
			end
			local meta = Meta:meta(self._type)
			return meta:ctor(self._rawval)
		else
			return VN.value(self:root())
		end
	end,

	assign = function(self, path, index, rawval, cbs)
		local node = self:root()
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end

		VN.assign(node, index, rawval, cbs)
	end,

    ctor = function(self, path, index, rawval)
		local node = self:root()
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end

        local new_node = VN.new(rawval)

        VN.ctor(node, index, new_node)
		
	end,

	insert = function(self, path, index, type, rawval, cbs)
		local node = self:root()
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end

		return VN.insert(node, index, rawval, type, cbs)
	end,

	remove = function(self, path, index, cbs)
		local node = self:root()
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end

		return VN.remove(node, index, cbs)
	end,

	move = function(self, path, from, to, cbs)
		local node = self:root()
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end

		return VN.move(node, from, to, cbs)
	end,

	attr = function(self, path, index, key)
		local node = self:root()
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end

		return VN.attr(node, index, key)
	end,

	set_attr = function(self, path, index, key, value, cbs)
		local node = self:root()
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end
		return VN.set_attr(node, index, key, value, cbs)
	end,

	attrs = function(self, path, index)
		local node = self:root()
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end
		
		return VN.attrs(node, index)
	end,

	node = function(self, path)
		local node = self:root()
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end

		return node
	end,

	on_node_ctor = function(self, node, index)
		-- sync
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO.PROPERTY_CTOR,
				params = {
					id = self._id,
					path = VN.path(node),
					index = index,
					val = Lib.copy(node[index])
				}
			}
		))

		Signal:publish(self, self.ON_NODE_CTOR, node, index)
		if log_enabled then
			Log(Def.LOG.TREE_NODE_CTOR, self._id, VN.path(node), index, Lib.v2s(node[index]))
		end
	end,

	on_node_assign = function(self, node, index)
		-- sync
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO.PROPERTY_ASSIGN,
				params = {
					id = self._id,
					path = VN.path(node),
					index = index,
					val = VN.value(node, index)
				}
			}
		))

		Signal:publish(self, self.ON_NODE_ASSIGN, node, index)
		if log_enabled then
			Log(Def.LOG.TREE_NODE_ASSIGN, self._id, VN.path(node), index, Lib.v2s(node[index]))
		end
	end,

	on_node_insert = function(self, node, index)
		-- sync
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO.PROPERTY_ARRAY_INSERT,
				params = {
					id = self._id,
					path = VN.path(node),
					index = index,
					val = Lib.copy(node[index])
				}
			}
		))

		Signal:publish(self, self.ON_NODE_INSERT, node, index)
		if log_enabled then
			Log(Def.LOG.TREE_NODE_INSERT, self._id, VN.path(node), index, Lib.v2s(node[index]))
		end
	end,

	on_node_remove = function(self, node, index, val)
		-- sync
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO.PROPERTY_ARRAY_REMOVE,
				params = {
					id = self._id,
					path = VN.path(node),
					index = index
				}
			}
		))

		Signal:publish(self, self.ON_NODE_REMOVE, node, index, val)
		if log_enabled then
			Log(Def.LOG.TREE_NODE_REMOVE, self._id, VN.path(node), index)
		end
	end,

	on_node_move = function(self, node, from, to)
		-- sync
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO.PROPERTY_ARRAY_MOVE,
				params = {
					id = self._id,
					path = VN.path(node),
					from = from,
					to = to
				}
			}
		))

		Signal:publish(self, self.ON_NODE_MOVE, node, from, to)
		if log_enabled then
			Log(Def.LOG.TREE_NODE_MOVE, self._id, VN.path(node), from, to)
		end
	end,

	on_node_attr_changed = function(self, node, index, key, value)
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO.PROPERTY_ATTR_CHANGED,
				params = {
					id = self._id,
					path = VN.path(node),
					index = tostring(index),
					key = key,
					value = value or ""
				}
			}
		))

		Signal:publish(self, self.ON_NODE_ATTR_CHANGED, node, index, key, value)
		if log_enabled then
			Log(Def.LOG.TREE_NODE_ATTR_CHANGE, self._id, VN.path(node), index, key, value)
		end
	end,
}

-----------------------------------------------------
function M:init()
	self._trees = {}
end

function M:create(type, rawval, id)
	id = id or GenUuid()

	rawval = rawval or {}
	local tree = Lib.derive(tree_class)
	tree:init(id, rawval, type)

	assert(not self._trees[id])
	self._trees[id] = tree

	return tree
end

function M:delete(id)
	self._trees[id] = nil
end

function M:tree(id)
	return assert(self._trees[id], tostring(id))
end

function M:set_log_ops(enabled)
	log_enabled = enabled
end

return M

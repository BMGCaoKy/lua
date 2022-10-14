local Meta = require "we.gamedata.meta.meta"
local Lang = require "we.gamedata.lang"
local TreeSet = require "we.gamedata.vtree"
local VN = require "we.gamedata.vnode"
local Recorder = require "we.gamedata.recorder"

return {
	VALUE = function(type)
		local meta = Meta:meta(type)
		assert(meta, type)

		return {
			ok = true,
			data = meta:ctor()
		}
	end,

	TREE_CREATE = function(type, rawval)
		local tree = TreeSet:create(type, rawval)

		return {ok = true, data = tree:id()}
	end,

	TREE_DELETE = function(id)
		TreeSet:delete(id)

		return {ok = true}
	end,

	TREE_SYNC = function(id)
		local tree = assert(TreeSet:tree(id))

		return {ok = true, data = tree:value()}
	end,

	NODE_COPY = function(id, path, index)
		local tree = assert(TreeSet:tree(id))
		local node = tree:root()
		for name in string.gmatch(path, "[^/]+") do
			node = node[name]
		end
		Meta:meta("Text"):set_processor(function(val)
			local id = Lang:copy_text(val.value)
			return { value = id }
		end)
		local val = VN.meta(node[index]):process(Lib.copy(node[index]))
		return {ok = true, data = Lib.copy(val)}
	end,

	OP_ASSIGN = function(id, path, index, rawval) 
		local tree = assert(TreeSet:tree(id))
		
		Recorder:start()
		tree:assign(path, index, rawval)
		Recorder:stop()

		return {ok = true}
	end,


    OP_CTOR = function(id, path, index, type)
        local tree = assert(TreeSet:tree(id))
		Recorder:start()
		tree:ctor(path, index, type)
		Recorder:stop()

		return {ok = true}
    end,

	OP_INSERT = function(id, path, index, type, rawval)
		local tree = assert(TreeSet:tree(id))

		Recorder:start()
		local idx = tree:insert(path, index, type, rawval)
		Recorder:stop()

		return {ok = true, data = idx}
	end,

	OP_REMOVE = function(id, path, index)
		local tree = assert(TreeSet:tree(id))

		Recorder:start()
		tree:remove(path, index)
		Recorder:stop()

		return {ok = true}
	end,

	OP_MOVE = function(id, path, from, to)
		local tree = assert(TreeSet:tree(id))

		Recorder:start()
		tree:move(path, from, to)
		Recorder:stop()

		return {ok = true}
	end,

	NODE_ATTR = function(id, path, index, key)
		local tree = assert(TreeSet:tree(id))
		local value = tree:attr(path, index, key)
		return {ok = true, data = value or ""}
	end,

	NODE_SET_ATTR = function(id, path, index, key, value)
		local tree = assert(TreeSet:tree(id))
		local value = tree:set_attr(path, index, key, value, ~VN.CTRL_BIT.RECORDE)	-- todo:liuchang Qt 主动设置的特性可能无法撤销
		return {ok = true, data = value or ""}
	end,

	NODE_ATTRS = function(id, path, index)
		local tree = assert(TreeSet:tree(id))
		local list = tree:attrs(path, index)
		return {ok = true, data = list}
	end,

	START_RECORD = function()
		Recorder:start()
	end,
	
	STOP_RECORD = function()
		Recorder:stop()
	end,

	SET_RECORD_ENABLE = function(enable)
		local old_enable = Recorder:enable()
		Recorder:set_enable(enable)
		return { data = old_enable}
	end
}

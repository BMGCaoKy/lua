local Module = require "we.gamedata.module.module"
local Meta = require "we.gamedata.meta.meta"
local Storage = require "we.view.scene.storage"

return {
	MODULE_LIST = function()
		local ret = {}

		for _, mo in ipairs(Module:list()) do
			table.insert(ret, mo:name())
		end

		return { ok = true, data = ret}
	end,

	ITEM_LIST = function(module)
		local ret = {}
		
		local m = Module:module(module)
		assert(m, module)

		for name in pairs(m:list()) do
			table.insert(ret, name)
		end

		return { ok = true, data = ret}
	end,

	ITEM_PROP = function(module, item)
		local m = Module:module(module)
		assert(m, module)

		local i = m:item(item)
		assert(i, item)

		return { ok = true, data = i:props()}
	end,

	ITEM_DATA = function(module, item)
		local m = Module:module(module)
		assert(m, module)

		local i = m:item(item)
		assert(i, item)

		return { ok = true, data = i:data():id()}
	end,

	ITEM_NEW = function(module, id, val)
		local m = Module:module(module)
		assert(m, module)

		local id = (id ~= "") and id
		local item = m:new_item(id, val)
		return { ok = true, data = item:id()}
	end,

	ITEM_COPY = function(module, item, id)
		local m = Module:module(module)
		assert(m, module)

		local new_item = m:copy_item(item, id)
		return { ok = true, data = new_item:id()}
	end,

	ITEM_DEL = function(module, item)
		local m = Module:module(module)
		assert(m, module)

		m:del_item(item)
		return {ok  = true}
	end,

	--storage
	STORAGE_REPETITION_ITEM = function(...)
		Storage:repetition_item({...})
		return {ok  = true}
	end,

	STORAGE_CREATE_FOLDER = function()
		Storage:create_folder()
		return {ok  = true}
	end,

	STORAGE_TIER_CHANGED = function(type, dstPath, movePaths)
		Storage:tier_changed(type, dstPath, movePaths)
		return {ok  = true}
	end,

	STORAGE_DELETE_ITEM = function(...)
		Storage:delete_item({...})
		return {ok  = true}
	end,
}

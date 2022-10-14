local Cjson = require "cjson"
local Module = require "editor.gamedata.module.module"
local Meta = require "editor.gamedata.meta.meta"
local Core = require "editor.core"
local Lang = require "editor.gamedata.lang"
local Mapping = require "editor.gamedata.module.mapping"
local Def = require "editor.def"
local Engine = require "editor.engine"
local UserData = require "editor.user_data"
local Var = require "editor.gamedata.var"
local Map = require "we.view.scene.map"

local M = {}

local notify = {
	ITEM_NEW = function(module, item)
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO_ITEM_NEW,
				params = {
					module = module,
					item = item
				}
			}
		))
	end,

	ITEM_DEL = function(module, item)
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO_ITEM_DEL,
				params = {
					module = module,
					item = item
				}
			}
		))
	end,

	PROPERTY_ASSIGN = function(module, item, path, index, val)
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO_PROPERTY_ASSIGN,
				params = {
					module = module,
					item = item,
					path = path,
					index = index,
					val = val
				}
			}
		))
	end,

	PROPERTY_CTOR = function(module, item, path, index, val)
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO_PROPERTY_CTOR,
				params = {
					module = module,
					item = item,
					path = path,
					index = index,
					val = val
				}
			}
		))
	end,

	PROPERTY_ARRAY_INSERT = function(module, item, path, index, val)
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO_PROPERTY_ARRAY_INSERT,
				params = {
					module = module,
					item = item,
					path = path,
					index = index,
					val = val
				}
			}
		))
	end,

	PROPERTY_ARRAY_REMOVE = function(module, item, path, index)
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO_PROPERTY_ARRAY_REMOVE,
				params = {
					module = module,
					item = item,
					path = path,
					index = index
				}
			}
		))
	end,

	PROPERTY_ARRAY_MOVE = function(module, item, path, from, to)
		Core.notify(Cjson.encode(
			{
				type = Def.PROTO_PROPERTY_ARRAY_MOVE,
				params = {
					module = module,
					item = item,
					path = path,
					from = from,
					to = to
				}
			}
		))
	end,

	MODIFY_FLAG = function(modified)
		Core.notify(Cjson.encode(
			{
				type = "MODIFY_FLAG",
				params = {
					modified = modified
				}
			}
		))
	end,
}

function M:notify(op, ...)
	print(op, ...)
	local func = assert(notify[op], op)
	func(...)
end

---------------------------------------------------------------
local processor = {
	MODULE_LIST = function()
		local ret = {}

		for name in pairs(Module:list()) do
			table.insert(ret, name)
		end

		return { ok = true, data = ret}
	end,

	META = function(type)
		local meta = Meta:meta(type)
		assert(meta, type)
		return {
			ok = true, 
			data = {
				specifier = meta:specifier(),
				name = meta:name(),
				info = meta:info()
			}
		}
	end,

	VALUE = function(type)
		local meta = Meta:meta(type)
		assert(meta, type)

		return {
			ok = true,
			data = meta:ctor()
		}
	end,

	VALUE_BY_PATH = function(module, item, path, index)
		local m = Module:module(module)
		assert(m, module)
		local i = m:item(item)
		assert(i, item)
		local obj = i:obj()
		for name in string.gmatch(path, "[^/]+") do
			obj = obj[name]
		end
		if index ~= "" then
			obj = obj[index]
		end
		return {
			ok = true,
			val =  Lib.copy(obj)
		}
	end,

	META_ENUM_LIST = function(type)
		local meta = Meta:meta(type)
		assert(meta:specifier() == "enum")

		return {
			ok = true,
			data = meta:list()
		}
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

	SET_TEMP_TYPE = function(type)
		Module:module("temp"):set_item_type(type)
		return { ok = true }
	end,

	ITEM = function(module, item)
		local m = Module:module(module)
		assert(m, module)

		local i = m:item(item)
		assert(i, item)

		return { ok = true, data = i:val()}
	end,

	ITEM_NEW = function(module, id, val)
		local m = Module:module(module)
		assert(m, module)

		local id = (id ~= "") and id
		local item = m:new_item(id, val)
		return { ok = true, data = item:id()}
	end,

	ITEM_COPY = function(module, item)
		local m = Module:module(module)
		assert(m, module)

		local new_item = m:copy_item(item)
		return { ok = true, data = new_item:id()}
	end,

	ITEM_DEL = function(module, item)
		local m = Module:module(module)
		assert(m, module)

		m:del_item(item)
		return {ok  = true}
	end,

	OP_ASSIGN = function(module, item, path, index, rawval)
		local m = Module:module(module)
		assert(m, module)

		local i = m:item(item)
		assert(i, item)

		i:modify(path, index, rawval)
		return {ok = true}
	end,

	OP_INSERT = function(module, item, path, index, type, rawval)
		local m = Module:module(module)
		assert(m, module)

		local i = m:item(item)
		assert(i, item)
		
		local idx = i:insert(path, index, type, rawval)

		return {ok = true, data = idx}
	end,

	OP_REMOVE = function(module, item, path, index)
		print(module, item, path, index)
		local m = Module:module(module)
		assert(m, module)

		local i = m:item(item)
		assert(i, item)
		
		print("path",path,"index",index)
		i:remove(path, index)

		return {ok = true}
	end,

	OP_MOVE = function(module, item, path, from, to)
		local m = Module:module(module)
		assert(m, module)

		local i = m:item(item)
		assert(i, item)

		i:move(path, from, to)

		return {ok = true}
	end,

	TEXT = function(key, sys)
		return {ok = true, data = Lang:text(key, sys)}
	end,

	SET_TEXT = function(key, text)
		Lang:set_text(key, text)
		return {ok = true}
	end,

	TAG_LIST = function(item)
		local m = Module:module("tag")
		assert(m, "tag")

		local i = m:item(item)
		assert(i, item)

		local tags = i:val()["tags"]

		return {ok = true,data = tags}
    end,

	TAG_NEW = function(item,key,text)
		Lang:set_text(key,text)
		local m = Module:module("tag")
		assert(m, "tag")

		local i = m:item(item)
		assert(i,item)

		i:insert("tags",nil,nil,key)

		return{ok = true}	
	end,

	TAG_DEL = function(item,index)
		local m = Module:module("tag")
		assert(m, "tag")

		local i = m:item(item)
		assert(i,item)
		print("index",index)
		i:remove("tags", index)
		return{ok = true}
	end,

	SAVE = function()
		Module:save()
		Lang:save()
		Mapping:save()
		Engine:save_all_map()
		UserData:save()
		Map:save()

		M:notify(Def.PROTO_MODIFY_FLAG, false)
		return {ok = true}
	end,

	VAR_KEY = function(page)
		local key = Var:get_vars(page)
		return {ok = true, data = key}
	end
}

M.processor = processor

return M

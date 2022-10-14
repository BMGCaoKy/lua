local Def = require "we.def"
local Seri = require "we.gamedata.seri"
local Module = require "we.gamedata.module.module"
local Setting = require "common.setting"

local M = {}

function M:init()
	self._ids = {}
	self._mapping = {}
	self._modified = false
end

function M:load()
	local data = Lib.read_json_file(Def.PATH_EXPORT_ID_MAPPING)
	for module, mapping in pairs(data) do
		self._mapping[module] = {}
		self._ids[module] = {}
		local _maxId = 0
		for id, item in pairs(mapping) do
			id = assert(math.tointeger(id))
			self._mapping[module][id] = item
			self._mapping[module][item] = id
			if _maxId < id then
				_maxId = id
			end
		end
		--self._mapping[module]["maxId"] = _maxId
		self._ids[module]["maxId"] = _maxId
	end
end

function M:save()
	if not self._modified then
		return
	end

	local data = {}
	for module, mapping in pairs(self._mapping) do
		data[module] = {}
		for key, val in pairs(mapping) do
			if type(key) == "number" then
				data[module][tostring(key)] = val
			end
		end
	end

	data["block"]["0"] = "/air" 
	Seri("json", data, Def.PATH_EXPORT_ID_MAPPING, true)

	self._modified = false
end

function M:register(module, item)
	item = string.format("%s/%s", Def.DEFAULT_PLUGIN, item)
	self._mapping[module] = self._mapping[module] or {}
	--local id = #self._mapping[module] + 1
	--local id = self._mapping[module]["maxId"] + 1
	local id = self._ids[module]["maxId"] + 1
	self._ids[module]["maxId"] = id
	assert(not self._mapping[module][item])
	self._mapping[module][id] = item
	self._mapping[module][item] = id

	self._modified = true

	self:save()

	Setting:loadId()
end

function M:unregister(module, item)
	item = string.format("%s/%s", Def.DEFAULT_PLUGIN, item)

	assert(self._mapping[module], module)

	local id = assert(self._mapping[module][item], item)
	self._mapping[module][item] = nil
	self._mapping[module][id] = nil

	self._modified = true

	self:save()
end

function M:data()
	return {
		mapping = self._mapping
	}
end

function M:id2name(module, id)
	return self._mapping[module][id]
end

function M:name2id(module, item)
	return self._mapping[module][item]
end

return M

local Def = require "editor.def"
local Seri = require "editor.gamedata.seri"
local Module = require "editor.gamedata.module.module"

local M = {}
--留给官方方块的id
M.MAPPING_OFFSET = 3000

function M:init()
	self._mapping = {}
	self._user_mapping = {}
	self._modified = false

	self:load()
end

function M:load()
	local data = Lib.read_json_file(Def.PATH_GAME_META_ID_MAPPING)
	for module, mapping in pairs(data) do
		self._mapping[module] = {}
		self._user_mapping[module] = {}
		for id, item in pairs(mapping) do
			id = assert(math.tointeger(id))
			if id > self.MAPPING_OFFSET then
				id = id - self.MAPPING_OFFSET
				self._user_mapping[module][id] = item
				self._user_mapping[module][item] = id
			else
				self._mapping[module][id] = item
				self._mapping[module][item] = id
			end
		end
	end

	Lib.emitEvent(Event.EVENT_EDITOR_MAPPING_LOADED)
end

function M:save()
	if self._modified then
		local data = {}
		for module, mapping in pairs(self._mapping) do
			data[module] = {}
			for key, val in pairs(mapping) do
				if type(key) == "number" then
					data[module][tostring(key)] = val
				end
			end
		end

		for module, mapping in pairs(self._user_mapping) do
			data[module] = data[module] or {}
			for key, val in pairs(mapping) do
				if type(key) == "number" then
					data[module][tostring(key + self.MAPPING_OFFSET)] = val
				end
			end
		end

		Seri("json", data, Def.PATH_GAME_META_ID_MAPPING, true)
		self._modified = false
	end
end

function M:dump()
	Lib.emitEvent(Event.EVENT_EDITOR_MAPPING_DUMP)
end

function M:register(module, item)
	self._user_mapping[module] = self._user_mapping[module] or {}
	local id = #self._user_mapping[module] + 1
	assert(not self._user_mapping[module][item])
	self._user_mapping[module][id] = item
	self._user_mapping[module][item] = id
	self._modified = true

	Lib.emitEvent(Event.EVENT_EDITOR_MAPPING_MODIFY)
end

function M:remove(module, item)
	local m
	if self._mapping[module][item] then
		m = self._mapping[module]
	elseif self._user_mapping[module] and self._user_mapping[module][item] then
		m = self._user_mapping[module]
	end
	if m then
		local id = m[item]
		m[item] = nil
		m[id] = nil

		self._modified = true
		Lib.emitEvent(Event.EVENT_EDITOR_MAPPING_MODIFY)
	end
end

function M:data()
	return {
		mapping = self._mapping,
		user_mapping = self._user_mapping
	}
end


return M

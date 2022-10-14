local IWorld = require "we.engine.engine_world"
local Cjson = require "cjson"
local Core = require "editor.core"
local Signal = require "we.signal"

local M = {}

M.SIGNAL = {
	DESTROY = "DESTROY"
}

function M:create_region()
	self._data = nil
	self._region = assert(IWorld:create_instance({ class = "RegionPart" }))
	return self._region
end

function M:set_data(data)
	self._data = data
end

function M:change_data(min, max)
	assert(self._data)
	self._data["region"]["min"] = min
	self._data["region"]["max"] = max
end

function M:delete()
	if self._region then
		IWorld:remove_instance(self._region)
		self._region = nil
		self.data = nil
		Signal:publish(self, M.SIGNAL.DESTROY)
	end
end

function M:finish()
	Core.notify(Cjson.encode{
		type = "REGION_FINISH"
	})
end

function M:cancel()
	Core.notify(Cjson.encode{
		type = "DIALOG_CANCEL"
	})
end

return	M
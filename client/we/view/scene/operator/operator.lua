local Signal = require "we.signal"
local State = require "we.view.scene.state"
local Receptor = require "we.view.scene.receptor.receptor"

local M = {}

-- on receptor ability changed
local function update(self, receptor)
	for _, op in pairs(self._set) do
		op:set_enable(not not op:check(receptor))
	end
end

function M:init()
	self._set = {}
	self._monitor = nil

	for _, vnode in ipairs(State:operator()["items"]) do
		local code = assert(vnode["code"], tostring(vnode["code"]))
		local ok, ret = pcall(require, string.format("%s.operator_%s", "we.view.scene.operator", string.lower(code)))
		if ok then
			local op = Lib.derive(ret)
			op:init(vnode)

			assert(not self._set[code], tostring(code))
			self._set[code] = op
		end
	end

	Signal:subscribe(Receptor, Receptor.SIGNAL.ON_BIND_CHANGED, function(receptor)
		if self._monitor then
			self._monitor()
			self._monitor = nil
		end

		if receptor then
			self._monitor = Signal:subscribe(receptor, receptor.SIGNAL.ABILITY_CHANGE, function()
				update(self, receptor)
			end)
		end

		update(self, receptor)
	end)
end

function M:operator(code)
	return assert(self._set[code], tostring(code))
end

return M

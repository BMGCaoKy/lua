local birthPos = L("birthPos", {})
local data_state = require "editor.dataState"
local map_setting = require "editor.map_setting"

function birthPos:add(id, derive_obj, pos)
	map_setting:setBirthPos(pos + Lib.v3(1, 0.1, 1))
end

function birthPos:del(id)
	map_setting:setBirthPos()
end

function birthPos:load(id, pos)
	local name = self:getCfgById(id)
	self:rulerArithmeticAdd(name, pos, id)
end

RETURN(birthPos)

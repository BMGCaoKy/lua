local state = require "we.state"
local def = require "we.def"
local engine = require "we.engine"

local M = {}

function M.frame_to_chunk()
	if state:focus_class() == def.TFRAME then
		local focusobj = state:focus_obj()
		local chunkobj = engine:make_chunk(focusobj.min, focusobj.max)
		local obj = { pos = focusobj.min, data = chunkobj }
		state:set_focus(obj, def.TCHUNK)
		state:set_editmode(def.EMOVE)
		engine:editor_obj_type("TCHUNK")
	end
end

function M.frame_max_axis(min,max)
	local x = max.x - min.x + 1
	local y = max.y - min.y + 1
	local z = max.z - min.z + 1

	local l = math.max(x,y)
	l = math.max(l,z)
	return l
end


return M
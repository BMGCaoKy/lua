local Core = require "editor.core"
local Cjson = require "cjson"

local default

local function warp(tb, def)
	if #tb > 0 then
		return
	end

	for k, v in pairs(tb) do
		if type(v) == "table" and type(def[k]) == "table" then
			warp(tb[k], def[k])
		end
	end

	return setmetatable(tb, {__index = def})
end

local function load(name)
	local content = Core.OpenResourceByResName(name)
	
	-- remove BOM
	local c1, c2, c3 = string.byte(content, 1, 3)
	if (c1 == 0xEF and c2 == 0xBB and c3 == 0xBF) then	-- UTF-8
		content = string.sub(content, 4)
	elseif (c1 == 0xFF and c2 == 0xFE) then	-- UTF-16(LE)
		content = string.sub(content, 3)
	end
	
	return Cjson.decode(content)
end

local function init()
	default = load("Part.mtl")	-- todo
end

init()

return {
	template = function(name)
		local mtl = load(name)
		return warp(mtl, default)
	end
}

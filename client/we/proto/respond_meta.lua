local Meta = require "we.gamedata.meta.meta"
local Lang = require "we.gamedata.lang"
local TreeSet = require "we.gamedata.vtree"
local VN = require "we.gamedata.vnode"

return {
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

	HAS_META = function(type)
		local meta = Meta:meta(type)
		return {has = (meta ~= nil)}
	end,

	META_ENUM_LIST = function(type, param)
		local meta = Meta:meta(type)
		assert(meta:specifier() == "enum")

		return {
			ok = true,
			data = meta:list(param)
		}
	end
}

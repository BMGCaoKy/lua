--用来放一些多个模块都可以用的数据转换方法
local Meta = require "editor.gamedata.meta.meta"
local Def = require "editor.def"

local function convert_asset(data, global)
	if data == "" then
		return "" -- NOTE: 有地方不判断 nil, 直接用，所以不能为 nil, 比如 handles:EntityDead
	end

	return (not global) and ("@" .. data) or data
end

local mapping = {
	["CastSound"] = function(data)
		return {
			selfOnly = data.selfOnly,
			loop = data.loop,
			volume = data.volume.value,
			sound = convert_asset(data.sound.asset, true)
		}
	end,
	["DeadSound"] = function(data)
		return {
			delayTime = data.delayTime.value,
			selfOnly = data.selfOnly,
			loop = data.loop,
			volume = data.volume.value,
			sound = convert_asset(data.sound.asset, true)
		}
	end,
	["EntityEffect"] = function(data)
		if data.effect.asset ~= "" then
		return{
			yaw = data.yaw,
			selfOnly = data.selfOnly,
			once = data.once,
			pos = {
				x = data.pos.x,
				y = data.pos.y,
				z = data.pos.z
			},
			effect = convert_asset(data.effect.asset)
		}
		end
	end,
	["MissileEffect"] = function(data)
		if data.effect.asset ~= "" then
			local ret = {
				yaw = data.yaw,
				once = data.once,
				pos = {
					x = data.pos.x,
					y = data.pos.y,
					z = data.pos.z
				},
				effect = convert_asset(data.effect.asset)
			}
			if data.timeLimit then
				ret.time = data.time.value
			end
			return ret
		end
	end,
	["BoundingVolume"] = function(data)
		local boundingVolume = {}
		local params = {}
		table.insert(params,data.params.x)
		table.insert(params,data.params.y)
		table.insert(params,data.params.z)
		boundingVolume["type"] = data.type
		boundingVolume["params"] = params
		return boundingVolume
	end,
	["Time"] = function(data)
		return data.value
    end,
	["TalkList"] = function(data)
		local talk = {}
		for _,v in pairs(data.talk) do
			table.insert(talk,{
				["npc"] = v.npc,
				["msg"] = v.msg.value
			})
		end
		return talk
	end,
	["ScenePos"] = function(data)
		return {
			map = data.map,
			x = data.pos.x,
			y = data.pos.y,
			z = data.pos.z,
		}
	end,
	["SceneRegion"] = function(data)
		return {
			map = data.map,
			min = data.region.min,
			max = data.region.max
		}
	end,
	["Resource_Actor"] = function(data)
		return data.asset
	end,
	["BlockArray"] = function(data)
		if #data.blockArray > 0 then
			return data.blockArray
		end
	end,
	["ColorRGBA"] = function(data)
		return {data.r, data.g, data.b, data.a}
	end,
	["TipTypeCvr"] = function(data)
		return tonumber(data.type)
	end,
	["Text"] = function(data)
		return data.value
	end,
	[Def.TYPE_ASSET] = function(data, global)
		return convert_asset(data, global)
	end
}

return function(data, type, ...)
	if not type then
		if _G.type(data) == "table" then
			type = data[Def.OBJ_TYPE_MEMBER]
		end
	end

	local converter = mapping[type]
	if not converter then
		return data
	end

	return converter(data, ...)
end

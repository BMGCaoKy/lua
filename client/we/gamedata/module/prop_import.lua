local Def = require "we.def"

local M = {}

function M.original(v)
	return v
end

function M.num2bool(v)
	assert(v == 1 or v == 0)
	return v == 1
end

function M.asset(path, item)
	if not path or path == "" then
		return
	end
	local res_path
	local first_str = string.sub(path, 1, 1)
	if first_str == "@" then
		res_path = string.sub(path, 2)
	elseif first_str == "/" then
		res_path = Lib.combinePath("plugin", Def.DEFAULT_PLUGIN, path)
	else
		res_path = Lib.combinePath("plugin", Def.DEFAULT_PLUGIN, item:module_name(), item:id(), path)
	end
	return { asset = res_path }
end


function M.prefixless_asset(path)
	if not path or path == "" then
		return
	end
	local res_path
	local first_str = string.sub(path, 1, 1)
	if first_str == "/" then
		res_path = Lib.combinePath("plugin", Def.DEFAULT_PLUGIN, path)
	else
		res_path = "asset/" .. path
	end
	return { asset = res_path }
end

--类型的话则为大写

function M.Time(v)
	if v and v >= 0 then
		return { value = v }
	end
end

function M.Text(v)
	if v then
		return { value = v }
	end
end

function M.CastSound(v, item)
	if v then
		local ret = {
			selfOnly = v.selfOnly,
			loop = v.loop,
			volume = { value = v.volume },
			playRate = v.multiPly,
			sound = v.path and {asset = v.path} or M.asset(v.sound, item)
		}
		if true == v.is3dSound then
			ret.is3dSound = true
			ret.attenuationType = v.attenuationType
			ret.losslessDistance = v.losslessDistance
			ret.maxDistance = v.maxDistance
		end
		return ret
	end
end

function M.EntityEffect(v, item)
	if v then
		local asset = v.effect
		if string.find(asset, "@") == 1 then
			asset = string.gsub(asset, "@", "asset/")
		end
		return {
			selfOnly = v.selfOnly,
			once = v.once,
			pos = v.pos,
			yaw = v.yaw,
			effect = { asset = asset }
		}
	end
end

function M.MissileEffect(v, item)
	if v then
		return {
			effect = M.asset(v.effect, item),
			once = v.once,
			pos = v.pos,
			yaw = v.yaw,
			timeLimit = v.time and true or false,
			time = M.Time(v.time)
		}
	end
end

function M.ConsumeItemType(reloadName, reloadBlock)
	if not reloadName or reloadName == "" then
		return
	end

	if reloadName == "/block" then
		return {
			type = "Block",
			block = reloadBlock
		}
	else
		return {
			type = "Item",
			item = reloadName
		}
	end
end

return M
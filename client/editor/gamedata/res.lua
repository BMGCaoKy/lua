local Lfs = require "lfs"
local Core = require "editor.core"
local Def = require "editor.def"

local M = {}

function M:init()

end

function M.import(path)
	if not path or path == "" then
		return ""
	end
	local file, errmsg = io.open(path, "rb")
	assert(file, errmsg)

	local ext = string.match(path, "^%g+%.(%g+)$")
	local content = file:read("a")
	file:close()

	local md5 = Core.md5(content)
	local name = string.format("%s%s", md5, ext and string.format(".%s", ext) or "")
	local npath = Lib.combinePath(Def.PATH_GAME_META_ASSET, name)
	if Lfs.attributes(npath) then
		return name
	end

	local tmp = string.format("%s.__bak__", npath)
	file, errmsg = io.open(tmp, "w+b")
	assert(file, errmsg)
	file:write(content)
	file:close()

	local ret, errmsg = os.rename(tmp, npath)
	assert(ret, errmsg)

	return name
end

function M.list(path, filter)
	local ret = {}

	local exts = nil
	if filter then
		exts = {}
		for ext in string.gmatch(filter, "[%g]+") do
			exts[ext] = true
		end
	end

	path = Lib.combinePath(Def.PATH_ASSET_DIR, path)
	for fn in Lfs.dir(path) do
		if fn ~= "." and fn ~= ".." then
			local _tmp = Lib.combinePath(path, fn)
			if Lfs.attributes(_tmp, "mode") == "file" then
				local ext = string.match(fn, "^%g+%.(%g+)$")
				if not exts or exts[ext] then
					table.insert(ret, {value = _tmp })
				end
			end
		end
	end

	return ret
end

return M

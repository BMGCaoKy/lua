local Lfs = require "lfs"
local Core = require "editor.core"
local Def = require "we.def"

local M = {}

function M:init()

end

--资源选取现在只可以从当前游戏资源目录下选择，其他情况为出错
--后面会添加从远程下载的情况，到时再改这部分代码
function M.import(path, asset)
	if not path or path == "" then
		--如果Resource_ItemTexture这种结构体初始化时没有提供selector的值
		--在第一次撤回时在这里就会返回一个空值，而不是初始化时给asset设置的默认值
		return (asset and asset ~= "") and asset or ""
	end
	local currentdir = Lib.normalizePath(Lfs.currentdir())
	local path_game_asset = Def.PATH_GAME_ASSET
	if string.find(path_game_asset, currentdir, 1, true) == 1 then
		--path_game_asset = string.gsub(Def.PATH_GAME_ASSET, currentdir, ".")
		--lua的字符串替换有些字符似乎有问题
		path_game_asset = string.sub(path_game_asset, #currentdir + 2)
	end
	if string.find(path_game_asset, "./", 1, true) == 1 then
		path_game_asset = string.sub(path_game_asset, 3)
	end
	if string.find(path, "./", 1, true) == 1 then
		path = string.sub(path, 3)
	end
	if string.find(path, path_game_asset, 1, true) == 1 then
		path = string.sub(path, #path_game_asset + 1)
		return "asset/" .. path
	end
	--TODO chenzhang
	return path
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
				local ext = string.match(fn, "^.+%.(%g+)$")
				if not exts or exts[ext] then
					table.insert(ret, {value = _tmp })
				end
			end
		end
	end

	return ret
end

return M

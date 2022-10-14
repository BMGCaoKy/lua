
local gameName = L("gameName")

function ResLoader:addGame(game_name)
	gameName = game_name
	local resGroupMgr = ResourceGroupManager:Instance()
	local gameRoot = self:getGameRootDir()
	--加快客户端初始化速度，文件注册系统采用打包脚本输出的文件列表代替io遍历文件获取文件路径的形式，如果在启用列表，否则io遍历。
	local files = Lib.readGameJson("files.json") or {}
	resGroupMgr:addResourceList(gameRoot, gameName, files, "FileSystemIndexByPath")

	---加载游戏独立资源
	local rootPath = Root.Instance():getRootPath()
	local gameResPath = Lib.combinePath(rootPath, "Media", "GameRes", game_name) .. '/'

	if Lib.dirExist(gameResPath) then
		local gameFiles = Lib.read_json_file(Root.Instance():getRootPath()  .. "config/" .. game_name .. ".json" )
		if gameFiles then
			for k, v in pairs(gameFiles) do
				resGroupMgr:addResourceList(rootPath, k, v, "FileSystem", "General")
			end
		else
			local gameResDirList = {}
			Lib.getSubDirs(gameResPath, gameResDirList)
			for _, dir in pairs(gameResDirList) do
				resGroupMgr:addResourceLocation(rootPath, Lib.combinePath("Media", "GameRes", game_name, dir), "FileSystem", "General")
			end
		end
	end

	local locList = FileResourceManager:Instance():GetGameCustomFileNameIndexFolderList()
	local plugins = World.cfg.plugins or {}
	for _, plugin in pairs(plugins) do
		for _, loc in pairs(locList) do
			resGroupMgr:addResourceLocation(Root.Instance():getRootPath(), "Media/PluginRes/" .. plugin .. "/" .. loc, "FileSystem", "General")
		end
	end

	---加载游戏地图资源
	local gamePath = Root.Instance():getGamePath()
	local gameDir = Lib.combinePath(gameRoot, game_name) .. '/'
	if IS_EDITOR then 
		resGroupMgr:addResourceLocation(gameDir, "asset", "FileSystem", "Editor")
	end
	resGroupMgr:addResourceLocation(gamePath, "asset", "FileSystem", "Custom")
	local assetDirList = {}
	Lib.getSubDirs(gameDir, assetDirList)
	for _, dir in pairs(assetDirList) do
		if dir ~= "terrain" and dir ~= "lua" and dir ~= "map" then
			if IS_EDITOR then 
				resGroupMgr:addResourceLocation(gameDir, dir, "FileSystem", "Editor")
			end
			resGroupMgr:addResourceLocation(gamePath, dir, "FileSystem", "Custom")
		end
	end
	for _, loc in pairs(locList) do
		if loc ~= "terrain" and loc ~= "lua" and loc ~= "map" then
			resGroupMgr:addResourceLocation(gamePath, loc, "FileSystem", "Custom")
		end
	end
end
local lfs = require "lfs"
local triggerParser = require "common.trigger_parser"

local DEFAULT_BTS = {"triggers.bts"}
local DEFAULT_BTS_SERVER = {"triggers.bts"}
local DEFAULT_BTS_CLIENT = {"triggers_client.bts"}
local DEFAULT_BTS_FUNCS = {"trigger_funcs.bts"}
local truggerFuncList = nil
---@type setting
local setting = L("setting", {})
-- noCreateId 编辑器要定制

setting.noCreateId = {
--	name    	if auto create id
	block 	= 	true
}

local RootDir = Root.Instance():getGamePath()

local aloneList = T(setting, "aloneList")

local function fileTime(path)
	return lfs.attributes(RootDir .. path, "modification") or 0
end

local function readDir(dir, force)
	local path = dir .. "setting.lobj"
	local cfg = Lib.readGameLuaObject(path)
	if cfg then
		cfg._filename = "setting.lobj"
		cfg._time = fileTime(path)
	else
		path = dir .. "setting.json"
		cfg = Lib.readGameJson(path)
		if cfg then
			cfg._filename = "setting.json"
			cfg._time = fileTime(path)
		elseif force then
			cfg = {}
		else
			return nil
		end
	end
	cfg.dir = dir
	if dir == "" then 
		cfg.isLoadFuncs = true
	end
	return cfg
end

local function loadFuncs(cfg)
	if IS_EDITOR or not cfg.dir or not cfg.isLoadFuncs then
		return
	end

	Trigger.LoadTriggersCommon(cfg,{"plugin/myplugin/bluefunc"},true,trigger_exec_type.FUNCS)
end

local function loadTrigger(cfg)
	if IS_EDITOR or not cfg.dir then
		return
	end

	if not World.isClient then 
		Trigger.LoadTriggersCommon(cfg,cfg.btsList or DEFAULT_BTS,false,trigger_exec_type.NORMAL)
	else 
		Trigger.LoadTriggersCommon(cfg,cfg.clientBtsList or DEFAULT_BTS_CLIENT,false,trigger_exec_type.NORMAL_CLIENT)	
	end

	if cfg.worldIndex then
		World.cfgSet[cfg] = nil
	end

	if not World.cfgSet then
		World.cfgSet = {}
	end
	World.cfgSet[cfg] = cfg

	cfg.worldIndex = true

	if cfg.triggers then
		Trigger.LoadTriggers(cfg)

		if cfg.isLoadFuncs then
			loadFuncs(cfg)
		end
	end
end

local function isChanged(cfg)
	local dir = cfg.dir
	if not dir then
		return false
	end
	local filename = cfg._filename or "setting.json"
	if fileTime(dir .. filename) ~= cfg._time then
		return true
	end
	for path, time in pairs(cfg._btsTime or {}) do
		if fileTime(path) ~= (time or nil) then
			return true
		end
	end
	return false
end

local function copyCfg(cfg, newData, cpyFields)
	for _, key in ipairs(cpyFields) do
		newData[key] = cfg[key]
	end
	Trigger.ReleaseTriggers(cfg)
	for key in pairs(cfg) do
		cfg[key] = nil
	end
	for key, value in pairs(newData) do
		cfg[key] = value
	end
end

---@class Mods
local Mods = T(setting, "Mods")

---@class ModMeta
local ModMeta = T(setting, "ModMeta")
ModMeta.__index = ModMeta

function ModMeta:get(fullName)
	local cfg = self.list[fullName]
	if cfg~=nil then
		return cfg or nil
	end
	local i = assert(fullName:find("/"), fullName)
	local plugin = fullName:sub(1, i - 1)
	local name = fullName:sub(i + 1)
	local dir = string.format("plugin/%s/%s/%s/", plugin, self.name, name)
	cfg = readDir(dir)
	if cfg then
		cfg._name = name
		cfg.plugin = plugin
		cfg.fullName = fullName
		return self:set(cfg)
	elseif self:loadSheets() then
		cfg = self.list[fullName]
		if cfg then
			return cfg
		end
	else
		print("No plugin: " .. dir)
	end
	self.list[fullName] = nil
	return nil
end

local cpyFields = {"_name", "plugin", "modName", "displayName", "id"}
function ModMeta:set(cfg)
	local fullName = assert(cfg.fullName)
	local old = self.list[fullName]
	if old then
		copyCfg(old, cfg, cpyFields)
		cfg = old
	else
		local id = cfg.id or self.name2id[fullName]
		if not id then
			assert(not setting.noCreateId[self.name], fullName)
			id = #self.id2name + 1
		end
		cfg.id = id
		self.id2name[id] = fullName
		self.name2id[fullName] = id
		cfg.modName = self.name
		cfg.displayName = self.name .. ":" .. fullName
		self.list[fullName] = cfg
	end
	local baseTriggers = nil
	if cfg.base then
		local base = self:get(setting:relativeName(cfg, cfg.base)) or {}
		for k, v in pairs(base) do
			if k~="triggerSet" and k~="triggers" and k:sub(1,1)~="_" and cfg[k]==nil then
				cfg[k] = v
			end
		end
		baseTriggers = base.triggers
	end
	loadTrigger(cfg)
	if baseTriggers and not cfg.triggers and not cfg.btsList then	-- 兼容旧的bts继承方式
		cfg.triggers = baseTriggers
		Trigger.LoadTriggers(cfg)
	end
	if self.onLoad then
		self:onLoad(cfg, old~=nil)
	end
	--cfg.instance = self
	return cfg
end

local function formatPath(path)
	local ret =  string.gsub (path, "\\", "/")
	return ret
end

function ModMeta:loadSheets(changed)
	local oldSheets = self.sheets
	if not oldSheets then
		oldSheets = {}
	elseif not changed then
		return false
	end
	local sheets = {}
    for pluginName, pluginPath in Lib.dir("plugin", "directory") do
        local sheetsDir = pluginPath .. "/" .. self.name .. "/.sheets"
		local isFullPath
		local find, _ = string.find(formatPath(sheetsDir), formatPath(Root.Instance():getGamePath()), 1, true)
        if find then
            --在磁盘中找到这个目录，pluginName是目录名，比如“buff”，pluginPath是全路径
            isFullPath = true
        else
            --在逻辑资源zip中找到这个目录，pluginName是目录名，比如“buff”，pluginPath是相对路径“plugin/myplugin/buff”
            isFullPath = false
        end
        for name, path in Lib.dir(sheetsDir, "file", isFullPath) do
            local sheet = oldSheets[path]
            if sheet and sheet.time == fileTime(path) then
                sheets[path] = sheet
                oldSheets[path] = nil
            elseif name:match("%.(%g+)$") == "csv" then
                if changed then
                    changed[#changed + 1] = path
                end
                local list = {}
                local sheet = {
                    time = fileTime(path),
                    list = list,
                }
                local gameCsv
                if isFullPath then
                    gameCsv = Lib.read_csv_file(path)
                else
                    gameCsv = Lib.readGameCsv(path)
                end
                for _, cfg in ipairs(gameCsv or {}) do
                    cfg.plugin = pluginName
                    cfg.fullName = pluginName .. "/" .. cfg._name
                    cfg._sheet = sheet
                    list[cfg.fullName] = self:set(cfg)
				end
				sheets[path] = sheet
			end
		end
	end
	self.sheets = sheets
	for _, sheet in pairs(oldSheets) do
		for fullName, cfg in pairs(sheet.list) do
			if cfg._sheet == sheet and self.list[fullName]==cfg then
				self:set({fullName=fullName})
			end
		end
	end
	return next(sheets)~=nil
end

function ModMeta:loadAll()
	if not self.hasLoadAll then
		self.hasLoadAll = true
	end
	for pluginName, pluginPath in Lib.dir("plugin", "directory") do
		for name in Lib.dir(pluginPath .. "/" .. self.name, "directory", true) do
			self:get(pluginName .. "/" .. name)
		end
	end
	self:loadSheets()
	return self.list
end

function ModMeta:reloadAll(changed)
	for fullName, cfg in pairs(self.list) do
		if not cfg then
			self.list[fullName] = nil
		elseif isChanged(cfg) then
			self:reloadCfg(cfg)
			changed[#changed + 1] = cfg.displayName
		end
	end
	self:loadSheets(changed)
	self.hasLoadAll = false
end

function ModMeta:reloadCfg(cfg)
	local new = readDir(cfg.dir, true)
	new.fullName = cfg.fullName
	self:set(new)
	return new
end

function setting:modCfgs(modName)
	local cfgs = self:mod(modName):loadAll()
	for key, value in pairs(cfgs) do
		if value == false then
			cfgs[key] = nil
		end
	end
	return cfgs
end

function setting:fetch(modName, fullName)
	if not fullName then
		Lib.logWarning("[setting:fetch(modName)]: this usage is about to be deprecated!!!")
		return self:modCfgs(modName)
	end
	return self:mod(modName):get(fullName)
end

function setting:name2id(modName, fullName)
	local id = setting:mod(modName).name2id[fullName]
	if id == nil then
		Lib.logError("setting:name2id nil", modName, fullName)
	end
	return id
end

function setting:id2name(modName, id)
	return setting:mod(modName).id2name[id]
end

function setting:loadDir(dir, force)
	local cfg = aloneList[dir]
	if not cfg or force then
		cfg = readDir(dir, true)
		loadTrigger(cfg)
		aloneList[dir] = cfg
	end
	return cfg
end

function setting:loadId()
	local path = "id_mappings.json"
	local date = fileTime(path)
	if not date then
		return false
	end

	if not Lib.fileExists(Root.Instance():getGamePath()..path) then
		return false
	end

	if date==self._id_date then
		return false
	end
	self._id_date = date
	local ret = assert(Lib.readGameJson(path), path)
	for modName in pairs(self.noCreateId) do
		local id2name = {}
		local name2id = {}
		for id, fullName in pairs(ret[modName] or {}) do
			id = math.tointeger(id)
			assert(not id2name[id], id)
			--assert(not name2id[fullName], fullName)
			id2name[id] = fullName
			name2id[fullName] = id
		end
		local mod = self:mod(modName)
		mod.name2id = name2id
		mod.id2name = id2name
	end
	return true
end

---@return ModMeta
function setting:mod(modName)
	local mod = Mods[modName]
	if mod then
		return mod
	end
	---@type ModMeta
	mod = {
		name = modName,
		list = {},
		name2id = {},
		id2name = {},
		_meta = nil,
	}
	Mods[modName] = mod
	return setmetatable(mod, ModMeta)
end

function setting:reload()
	local changed = {}
	if self:loadId() then
		changed[#changed + 1] = "id_mappings"
	end
	for _, mod in pairs(Mods) do
		mod:reloadAll(changed)
	end
	local cpyFields = {"onReload"}
	for dir, cfg in pairs(aloneList) do
		if isChanged(cfg) then
			copyCfg(cfg, readDir(dir, true), cpyFields)
			changed[#changed + 1] = dir
			loadTrigger(cfg)
			if cfg.onReload then
				cfg:onReload()
			end
		end
	end
	return changed
end

function setting:relativePath(cfg, file)
	local head = file:sub(1,1)
	if head=="/" then
		return "plugin/" .. cfg.plugin .. file
	elseif head=="@" then
		return file:sub(2)
	else
		return cfg.dir .. file
    end
end

function setting:relativeName(cfg, name)
	return name:find("/") and name or cfg.plugin .. "/" .. name
end

--关联资源
local resKeys = {
	"icon", "actorName", "effect", "removeSound", "removeEffect", "pickSound", "pickEffect", 
	"modelMesh", "modelBlock", "modelPicture", "hitHeadEffect", "hitEffect", "hitEntitySound", 
	"hitSound", "deadSound", "deathEffect", "rebirthSound", "spawEffect", "hurtSound", 
	"texture", "defaultTexture", "quads", "startEffect", "startSound", "hitBlockSound", 
	"vanishEffect", "vanishSound", 
}
local resTableKeys = {
	effect = true, sound = true, 
}
--关联插件
local pluginKeys = {
	block = {"placeTestBlock"},
	buff = {"ownerBuffCfg", "buffCfg", "handBuff", "equip_buff", "passiveBuffs"},
	entity = {},
	missile = {},
	skill = {"castSkill", "hitEntitySkill", "hitSkill", "skill", "startSkill", "vanishSkill"},
}

function setting:getUsedResources(cfg, resources, bExtRes, hasLoad)
	print("setting:getUsedResources=====", cfg.fullName)
	resources = resources or {}
	hasLoad = hasLoad or {}

	for _, v in pairs(resKeys) do
		if cfg[v] then
			if type(cfg[v]) == "string" then 
				if not hasLoad[cfg[v]] then
					resources[#resources + 1] = cfg[v]
					hasLoad[cfg[v]] = true
				end
			elseif type(cfg[v]) == "table" then 
				for key, file in pairs(cfg[v]) do
					if not hasLoad[file] and resTableKeys[key] then
						resources[#resources + 1] = file
						hasLoad[file] = true
					end
				end
			end
		end
	end

	local fullName
	if bExtRes then 
		for modName, v in pairs(pluginKeys) do
			for _, pkey in pairs(v) do
				fullName = cfg[pkey]
				if type(fullName) == "table" then 
					for _, fname in pairs(fullName) do
						if hasLoad[modName.."/"..fname] then 
							goto CONTINUE2
						end

						local nCfg = setting:fetch(modName, fname)
						if nCfg then 
							resources = setting:getUsedResources(nCfg, resources, bExtRes, hasLoad)
						end
						hasLoad[modName.."/"..fname] = true

						::CONTINUE2::
					end
				elseif type(fullName) == "string" then 
					if hasLoad[modName.."/"..fullName] then 
						goto CONTINUE
					end

					local nCfg = setting:fetch(modName, fullName)
					if nCfg then 
						resources = setting:getUsedResources(nCfg, resources, bExtRes, hasLoad)
					end
					hasLoad[modName.."/"..fullName] = true
				end
				::CONTINUE::
			end
		end
	end

	return resources
end

setting:loadId()

RETURN(setting)

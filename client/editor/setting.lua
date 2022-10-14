local cjson = require "cjson"
local setting = require "common.setting"
local editorSetting = L("editorSetting", {})
local lfs = require "lfs"
local engine = require "editor.engine"

local function getNameByFullName(fullName)
    if not fullName then
        return
    end
	assert(type(fullName) == "string", fullName)
	local splitRet = Lib.splitString(fullName, "/")
	local len = #splitRet
	local name = len > 0 and splitRet[len]
	return name
end

local function CopyTable(tab)
    -- 使用lib.copy会把v3表里面的map值给去掉
	local function _copy(obj)
		if type(obj) ~= "table" then
			return obj
		end
		local new_table = {}
		for k, v in pairs(obj) do
			new_table[_copy(k)] = _copy(v)
		end
		return setmetatable(new_table, getmetatable(obj))
	end
	return _copy(tab)
end


function editorSetting:saveValueByKey(mod, fullName, key, value, isSave, isCreate)
    -- 传入的key可以为xxx.xxx.xxx形式的字符串，扩展为写入多个层级内的配置文件
    fullName = getNameByFullName(fullName)
    local function saveLevelData(data)
        assert(data and data.cfg, key)
        local keyList = Lib.splitString(key, ".")
        local teamCfg = data.cfg
        for index = 1, #keyList - 1 do
            local v = keyList[index]
            assert(teamCfg and teamCfg[v], key .. "level is error")
            teamCfg = teamCfg[v]
        end
        teamCfg[keyList[#keyList]] = value
        data.isChange = true
    end
    local data
    if isSave then
        data = self:fetchImp(mod, fullName, isCreate)
    else
        data = self:fetch(mod, fullName, isCreate)
    end
    saveLevelData(data)
end

function editorSetting:getValueByKey(mod, fullName, key, isCreate)
	fullName = getNameByFullName(fullName)
    local data = editorSetting:fetch(mod, fullName, isCreate)
    if not data or not data.cfg then
        return
    end
    -- 传入的key可以为xxx.xxx.xxx形式的字符串，扩展为读取多个层级内的配置文件
    local keyList = Lib.splitString(key, ".")
    local value = data.cfg
    for k, v in pairs(keyList) do
        if not value then
            return
        end
        value = value[v]
    end
    return value
end

function editorSetting:createSettingFile(dirPath, fileName)
    local function createAndSaveFile()
        Lib.mkPath(dirPath)
        local createSuccess = Lib.saveGameJson(fileName, {}, dirPath)
        return createSuccess ~= false
    end

    local tryCount = 3
    local createSuccess = createAndSaveFile()
    if not createSuccess and tryCount > 0 then
        createSuccess = createAndSaveFile()
        tryCount = tryCount - 1
    end
    assert(createSuccess, "GameGsonFile create fail!!!")
end

function editorSetting:fetch(mod, Name, isCreate)
    Name = getNameByFullName(Name)
    self._cacheData = self._cacheData or {}
    local data = self._cacheData[mod]
    if not data or (Name and not data[Name]) then
        data = not data and {} or data
        self._cacheData[mod] = data      
        local tmpData = CopyTable(self:fetchImp(mod, Name, isCreate))
        if mod == "global" then
            data[mod] = tmpData
        else
            data[Name] = tmpData
        end
    end
    if (not Name) or Name == " " then
		return data[mod]
	end
	assert(data, string.format("mod %s is not exist", mod))
	return data[Name]
end

function editorSetting:fetchImp(mod, Name, isCreate) --global: name is nil, mod is "global"
	Name = getNameByFullName(Name)
    self._data = self._data or {}
    local data = self._data[mod]
	if not data or (Name and not data[Name]) then
        data = not data and {} or data
        self._data[mod] = data
        if mod == "global" then
            local dirPath = Root.Instance():getGamePath() .. "setting.json"
            local ret = Lib.read_json_file(dirPath)
			assert(ret, dirPath)
            data[mod] = {cfg = ret, isChange = false}
		else
			local dirPath = Root.Instance():getGamePath() .. "plugin/myplugin/" .. mod .. "/" .. Name
			local filePath = dirPath .. "/setting.json"
			local file, err = io.open(filePath, "r")
			if file then
				file:close()
			elseif isCreate then
				self:createSettingFile(dirPath, "/setting.json")
			end
			local ret = Lib.read_json_file(filePath)
			assert(ret and not ret.dir, filePath)
			data[Name] = {cfg = ret, isChange = false}
        end
	end
	if (not Name) or Name == " " then
		return data[mod]
	end
	assert(data, string.format("mod %s is not exist", mod))
	return data[Name]
end

function editorSetting:save(mod, fullName)
	fullName = getNameByFullName(fullName)
    local data = self._data[mod]
    local ok, content
    if mod == "global" then
        local gData = data[mod]
        if gData.isChange then
		    Lib.saveGameJson("setting.json", gData.cfg)
            data.isChange = false
        end
	else
		--print("save",fullName, mod, data[fullName] and data[fullName].isChange, data[fullName] and Lib.v2s(data[fullName].cfg, 2))
        if data[fullName] and data[fullName].isChange then
            local path = "plugin/myplugin/" .. mod .. "/" .. fullName .. "/setting.json"
            Lib.saveGameJson(path, data[fullName].cfg)
            data[fullName].isChange = false
        end
    end
end

function editorSetting:saveCache(mod, fullName)
    fullName = getNameByFullName(fullName)
    if mod == "global" then
        if self._data[mod] then
            self._data[mod][mod] = CopyTable(self._cacheData[mod][mod])
            if self._data[mod][mod].isChange then
                engine:set_bModify(true)
            end
        end
    else
        self._data[mod][fullName] = CopyTable(self._cacheData[mod][fullName])
        if self._data[mod][fullName].isChange then
            engine:set_bModify(true)
        end
    end
end

function editorSetting:setPlaceObjChange(mod, fullName, isChange)
    local gData = self._data[mod]
    if gData and not gData[fullName] and mod == "block" then
        gData[fullName] = self:fetch(mod, fullName)
    elseif not gData or not (gData and gData[fullName]) then
        return
    end
    gData[fullName].isChange = isChange
end

function editorSetting:saveAll(ignoreEvent)
    local data = self._data
    local ok, content
    for mod, _data in pairs(data or {}) do
        if mod == "global" then
            local gData = _data[mod]
            if gData.isChange then
                Lib.saveGameJson("setting.json", gData.cfg)
                gData.isChange = false
            end
        else
            for fullName, tdata in pairs(_data) do
                if tdata.isChange then
                    local path = "plugin/myplugin/" .. mod .. "/" .. fullName .. "/setting.json"
                    Lib.saveGameJson(path, tdata.cfg)
                    tdata.isChange = false
                    if not ignoreEvent then
                        Lib.emitEvent(Event.EVENT_SAVE_FILE_CHANGE, {mod = mod, name = fullName})
                    end 
                end
            end
        end
    end
end

function editorSetting:clearData(mod, name)
	name = getNameByFullName(name)
    local data = self._cacheData[mod]
    if not data then
        return
    end
    if mod == "global" then
        self._cacheData[mod] = nil
    else
        data[name] = nil
    end
end

RETURN(editorSetting)

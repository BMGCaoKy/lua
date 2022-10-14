
local lfs = require "lfs"
local base = require "editor.edit_record.base"
local stageSetting = require "editor.stage_setting"
local similarity = L("similarity", {})

local mapPosChanged = {}
local fileChanged = {}
local getFileContent = base.getFileContent
local saveFile = base.saveFile
local getEditRecordPath = base.getEditRecordPath

local function posToKey(pos)
    local tb = {math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)}
    return table.concat(tb, ",")
end

local function namePosToKey(name, pos)
    local tb = {name, math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)}
    return table.concat(tb, ",")
end

local function getSimilarChangedPath()
    return string.format("%schanged.json", getEditRecordPath())
end

local function getMapBlockChangedPath(mapName)
    local gamePath = Root.Instance():getGamePath()
    return string.format("%smap/%s/blocksChanged.json", gamePath, mapName)
end

local function getMapOriginSettingPath(mapName)
    local gamePath = Root.Instance():getGamePath()
    return string.format("%smap/%s/originSetting.json", gamePath, mapName)
end

local function getMapSettingPath(mapName)
    local gamePath = Root.Instance():getGamePath()
    return string.format("%smap/%s/setting.json", gamePath, mapName)
end

local function getChangedFilePath()
    return string.format("%schangedFile.json", getEditRecordPath())
end

local function getStandardGlobalSettingPath()
    return string.format("%sglobal.json", getEditRecordPath())
end

local function getGlobalSetting()
    local gamePath = Root.Instance():getGamePath()
    local path = string.format("%ssetting.json", gamePath)
    return getFileContent(path)
end

local function getStandardPlayerSettingPath()
    return string.format("%splayer.json", getEditRecordPath())
end

local function getPlayerSetting()
    local gamePath = Root.Instance():getGamePath()
    local path = string.format("%splugin/myplugin/entity/player1/setting.json", gamePath)
    return getFileContent(path)
end

local function isSameValue(v1, v2)
    local type1, type2 = type(v1), type(v2)
    if type1 == "number" and type2 == "number" then
        local int1, int2 = math.tointeger(v1), math.tointeger(v2)
        if int1 and int2 then
            return int1 == int2
        end
    end
    return v1 == v2
end

local function getLength(array)
    local count = 0
    for _ in pairs(array) do
        count = count + 1
    end
    return count
end

local function calculateChangedCount(tb1, tb2, parentKey)
    local type1, type2 = type(tb1), type(tb2)

    if type1 ~= "table" and type2 ~= "table" then
        return isSameValue(tb1, tb2) and 0 or 1
    end

    if not tb2 then
        tb2 = {}
    end

    --type: array
    if tb1[1] then
        return math.abs(getLength(tb1) - (tb2[1] and getLength(tb2) or 0))
    end

    --type: table
    local diffCount = 0
    for k, v in pairs(tb1) do
        local ret = calculateChangedCount(v, tb2[k], k)
        if ret ~= 0 then
            Lib.logInfo(string.format("similarity:parentKey:%s, changed key:%s, count:%s", parentKey, k, ret))
            diffCount = diffCount + ret
        end
    end
    for k, v in pairs(tb2) do
        if tb1[k] == nil then
            Lib.logInfo(string.format("similarity:parentKey:%s, added key:%s, count:%s", parentKey, k, 1))
            diffCount = diffCount + 1
        end
    end
    return diffCount
end


local function getEffectiveMaps()
    local effectiveMaps = {}
    local stages = stageSetting:getStageCfgList()
    for _, stage in ipairs(stages) do
        local mapName = stage.map
        effectiveMaps[mapName] = true
        local mapPath = getMapSettingPath(mapName)
        local mapCfg = getFileContent(mapPath)
        local nextOne = false
        for _, entityCfg in ipairs(mapCfg.entity or {}) do
            if entityCfg.cfg == "myplugin/endPoint" then
                nextOne = true
                goto continue
            end
        end
        ::continue::
        if not nextOne then
            break
        end
    end
    return effectiveMaps
end

local function isSupportSimilarCalculate()
    return base.enable
end

local function getTypeCChangedCount()

    local function checkBlockCount(tb)
        local count = 0
        for _ in pairs(tb) do
            count = count + 1
        end
        return count
    end

    local function compareDiffCount2(tb1, tb2)
        local function sortOut(tb)
            local temp = {}
            for _, data in ipairs(tb) do
                local key = namePosToKey(data.cfg, data.pos)
                local count = temp[key] or 0
                temp[key] = count + 1
            end
            return temp
        end

        local sortTb1 = sortOut(tb1)
        local sortTb2 = sortOut(tb2)
        local count = 0
        for key, num in pairs(sortTb1) do
            local num2 = sortTb2[key]
            if num2 then
                count = count + math.abs(num - num2)
            else
                count = count + num
            end
            sortTb2[key] = nil
        end
        for key, num in pairs(sortTb2) do
            count = count + num
        end
        return count
    end

    local maps = getEffectiveMaps()
    local itemCount, npcCount, blockCount = 0, 0, 0
    for mapName in pairs(maps) do
        local oriPath = getMapOriginSettingPath(mapName)
        local path = getMapSettingPath(mapName)
        local oriCfg = getFileContent(oriPath)
        local cfg = getFileContent(path)
        itemCount = itemCount + compareDiffCount2(oriCfg.item or {}, cfg.item or {})
        npcCount = npcCount + compareDiffCount2(oriCfg.entity or {}, cfg.entity or {})

        local changedBlockPath = getMapBlockChangedPath(mapName)
        local changed = getFileContent(changedBlockPath)
        blockCount = blockCount + checkBlockCount(changed)
    end
    return itemCount + npcCount + blockCount
end

local function getFileChangedCount()
    local changedFilePath = getChangedFilePath()
    local data = getFileContent(changedFilePath)
    local fileChangeCounts = {}
    for mod, dict in pairs(data) do
        local count = 0
        for _ in pairs(dict) do
            count = count + 1
        end
        fileChangeCounts[mod] = count
    end
    return fileChangeCounts
end

local function getGlobalSettingChangedCount()
    local standardGlobal = getFileContent(getStandardGlobalSettingPath())
    local global = getGlobalSetting()
    return calculateChangedCount(standardGlobal, global, "global")
end

local function getPlayerSettingChangedCount()
    local standardPlayer = getFileContent(getStandardPlayerSettingPath())
    local player = getPlayerSetting()
    return calculateChangedCount(standardPlayer, player, "player")
end

local function getAllChangedData()
    Lib.logInfo("similarity:============check global...")
    local globalChangedCount = getGlobalSettingChangedCount()
    Lib.logInfo("similarity:============check player...")
    local playerChangedCount = getPlayerSettingChangedCount()
    local typeCChangedCount = getTypeCChangedCount()
    local fileChangedCount = getFileChangedCount()

    local changedData = {
        A = globalChangedCount,
        B = playerChangedCount,
        C = typeCChangedCount,
        D1 = fileChangedCount.block or 0,
        D2 = fileChangedCount.item or 0,
        D3 = fileChangedCount.entity or 0
    }
    local changedDataInfo = {
        A_global = globalChangedCount,
        B_player = playerChangedCount,
        C_map_npc_dropItem_moveBlock = typeCChangedCount,
        D_file = fileChangedCount
    }
    Lib.logInfo("similarity:===========all", Lib.v2s(changedDataInfo))
    return changedData
end

function similarity:addChangedBlock(map, pos, oldId, newId)
    if not isSupportSimilarCalculate() then return end

    local mapName = type(map) == "string" and map or map.name
    local changed = mapPosChanged[mapName]
    if not changed then
        local path = getMapBlockChangedPath(mapName)
        changed = getFileContent(path)
        mapPosChanged[mapName] = changed
    end
    local key = posToKey(pos)
    local oldValue = T(changed, key, {oldId = oldId})
    if oldValue.oldId == newId then
        changed[key] = nil
    end
end


function similarity:addChangedFileName(mode, name)
    if not isSupportSimilarCalculate() then return end

    if name == "player1" then return end

    if not next(fileChanged) then
        local path = getChangedFilePath()
        fileChanged = getFileContent(path)
    end
    local modList = T(fileChanged, mode)
    modList[name] = true
end

function similarity:init()
    if not isSupportSimilarCalculate() then return end

    Lib.subscribeEvent(Event.EVENT_SAVE_FILE_CHANGE, function(data)
        similarity:addChangedFileName(data.mod, data.name)
    end)

    local globalPath = getStandardGlobalSettingPath()
    local attr = lfs.attributes(globalPath)
    if attr and attr.mode == "file" then
        return
    end

    saveFile(globalPath, getGlobalSetting())
    local playerPath = getStandardPlayerSettingPath()
    saveFile(playerPath, getPlayerSetting())

    local gamePath = Root.Instance():getGamePath()
    local dir = string.format("%smap/", gamePath)
    for mapName in lfs.dir(dir) do
        if mapName ~= "." and mapName ~= ".." and string.sub(mapName, 1, 3) == "map" then
            local cfgPath = getMapSettingPath(mapName)
            local oriPath = getMapOriginSettingPath(mapName)
            saveFile(oriPath, getFileContent(cfgPath))
        end
    end
end

function similarity:saveAll()
    if not isSupportSimilarCalculate() then return end

    for mapName, changed in pairs(mapPosChanged) do
        local path = getMapBlockChangedPath(mapName)
        saveFile(path, changed)
    end

    if next(fileChanged) then
        local changedFilePath = getChangedFilePath()
        Lib.logInfo("similarity:===========fileChangedCount", changedFilePath, Lib.v2s(fileChanged))
        saveFile(changedFilePath, fileChanged)
    end

    local changedData = getAllChangedData()
    local changedPath = getSimilarChangedPath()
    saveFile(changedPath, changedData)
end

return similarity
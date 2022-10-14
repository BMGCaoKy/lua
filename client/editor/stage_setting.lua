local data_state = require "editor.dataState"
local cjson = require "cjson"
local engine = require "editor.engine"
local setting = require "common.setting"
local mapSetting = require "editor.map_setting"
local lfs = require "lfs"
local stageCountLimit = 5
local globalSetting = require "editor.setting.global_setting"

local M = {}

local fullName = "myplugin/main"
local settingPath = "plugin/myplugin/stage/main/setting.json"
local curChapterID = 1
local mapPath

function M:init()
    self.settingContent = Lib.readGameJson(settingPath)
	if not self.settingContent then return end
    self.chapterSettings = self.settingContent.chapters
    self.stageSettings = self.chapterSettings[curChapterID].stages
    self.copyCount = 0
    self.curStage = self.chapterSettings[curChapterID].testStage
    assert(self.curStage, "chapterSetting must have [testStage] !!!")
    mapPath = Root.Instance():getGamePath() .. "map/"
end

local function saveMapPoint(firstStageMap)
    local mapPoint = {
        initPos = Lib.copy(globalSetting:getInitPos()),
        revivePos = Lib.copy(globalSetting:getRevivePos()),
        startPos = Lib.copy(globalSetting:getStartPos())
    }
    for key, point in pairs(mapPoint) do
        if point.map then
            point.map = firstStageMap
        else
            point[1].map = firstStageMap
        end
        print(key, Lib.v2s(point))
    end
    globalSetting:saveInitPos(mapPoint.initPos, true)
    globalSetting:saveRevivePos(mapPoint.revivePos, true)
    globalSetting:saveStartPos(mapPoint.startPos, true)
end

function M:onStagesChanged(curStage)
    self.curStage = curStage or self.curStage
    self:save()
    Lib.emitEvent(Event.EVENT_STAGE_LIST_CHANGED)
    globalSetting:saveTestMap(self.stageSettings[self.curStage].map, true)
    local firstStageMap = self.stageSettings[1].map
    local pos = mapSetting:get_pos(firstStageMap) or {}
    pos = pos.pos or {}
    globalSetting:saveDefaultMap(firstStageMap, true)
    -- saveMapPoint(firstStageMap)  会引起游戏闪退，后面再修
end

function M:save()
    self.chapterSettings[curChapterID].testStage = self.curStage
    Lib.saveGameJson(settingPath, self.settingContent)
end

function M:getStageList()
    local stages = {}
    for i, stage in ipairs(self.stageSettings) do
        stages[i] = stage.name
    end
    return stages
end

function M:getStageIconList()
    local lists = {}
    for i, list in ipairs(self.stageSettings) do
        lists[i] = list.icon
    end
    return lists
end


function M:setStageName(index, name)
    local stage = assert(self.stageSettings[index], index)
    stage.name = name
end

function M:changeStageOrder(index, isForward)
    local curStage = self.curStage
    local i1, i2
    if isForward then
        i1, i2 = index - 1, index
    else
        i1, i2 = index, index + 1
    end
    local settings = self.stageSettings
    if i1 < 1 or i2 > #settings then
        return
    end
    settings[i1], settings[i2] = settings[i2], settings[i1]
    if curStage == i1 then
        curStage = curStage + 1
    elseif curStage == i2 then
        curStage = curStage - 1
    end
    self:onStagesChanged(curStage)
end

function M:deleteStage(index)
    local curStage = self.curStage
    assert(curStage ~= index)
    local settings = self.stageSettings
    local mapName = self.stageSettings[index].map
    local map = World.CurWorld:getOrCreateStaticMap(mapName)
    if map then
        map:close()
    end
    handle_mp_editor_command("delete_map", {map_name = mapName})
    table.remove(settings, index)
    CGame.instance:deleteDir(mapPath .. mapName)
    curStage = curStage > index and curStage - 1 or curStage
    self:onStagesChanged(curStage)
end

local function delPointEntity(mapName)
    local path = "map/" .. mapName .. "/setting.json"
    local mapData = Lib.readGameJson(path)
    if mapData and mapData.entity then
        for k,v in pairs(mapData.entity) do
            if v.derive and v.derive.pointEntity then
                mapData.entity[k] = nil
            end
        end
    end
    Lib.saveGameJson(path, mapData)
end

function M:copyStage(index)
    local settings = self.stageSettings
    if #settings >= stageCountLimit then
        Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("stage_count_limited"), 20)
        return
    end
    local distName = "map" .. "-" .. os.time()
    if lfs.attributes(mapPath .. distName, "mode") then--already exit map file
        Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("stage_add_frequently"), 20)
        return
	end
    local stageCfg
    if not index then
        stageCfg = self.chapterSettings[curChapterID].stageTemplate
        assert(stageCfg, "chapterSetting must have [stageTemplate] !!!")
    else
        stageCfg = assert(settings[index], index)
    end
    local count = self.copyCount
    count = count + 1
    local srcName = stageCfg.map
    local newCfg = Lib.copy(stageCfg)
    newCfg.map = distName

    local mapNmae = ""
    local tempName = self:split(stageCfg.name, "-")
    if tonumber(tempName[#tempName]) and #tempName > 2 then
        local name = ""
        local index = tonumber(tempName[#tempName]) + 1
        for i = 1, #tempName - 1 ,1 do 
            name = name .. tempName[i] .. "-"
        end
        mapNmae = name .. index
    else
        mapNmae = stageCfg.name .. "-" .. count
    end

    if Lib.getStringLen(mapNmae) > 16 then
        local tempStr = Lib.subString(mapNmae, 14)
        newCfg.name = tempStr .. "-" .. count
    else
        newCfg.name = mapNmae
    end

    self.copyCount = count
    settings[#settings + 1] = newCfg
    CGame.instance:copyDir(mapPath .. srcName, mapPath .. distName)
    self:onStagesChanged()
    delPointEntity(distName)
    
    Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("stage_add_successfully"), 20)
end

function M:split( str,reps )
    local resultStrList = {}
    string.gsub(str,'[^'..reps..']+',function ( w )
        table.insert(resultStrList,w)
    end)
    return resultStrList
end

function M:switchStage(index)
    Entity:clearMonsterList()
    Entity:clearVectorList()
    Lib.emitEvent(Event.EVENT_EMPTY_STATE)
    Lib.emitEvent(Event.EVENT_SWITCH_STAGE)
    local stageCfg = self.stageSettings[index] 
    local mapName = self.stageSettings[index].map
    local oldObj = handle_mp_editor_command("get_player_pos", {dontEncode = true})
    local newObj = mapSetting:get_pos(mapName)
    if not newObj then
        local cfg = Lib.readGameJson("map/".. mapName .."/setting.json")
        newObj = {
            pos = cfg.pos,
            yaw = cfg.yaw,
            pitch = cfg.pitch,
        }
    end
    if not next(newObj) then
        newObj = oldObj
        assert(newObj and next(newObj))
    end
    local targetMapId = World.CurWorld:getOrCreateStaticMap(mapName).id
    handle_mp_editor_command("change_map", {
        old_obj = oldObj,
        new_obj = newObj,
        name = mapName,
        id = targetMapId,
        static = true,
    })
    self:onStagesChanged(index)
    CGame.instance:onEditorDataReport("stage_jump_success", "")
end

function M:renameStage(index, name)
    self.stageSettings[index].name = name
    self:save()
end

function M:getStageIndexByMap(map)
    for index, stage in ipairs(self.stageSettings or {}) do
        if stage.map == map then
            return index
        end
    end
end

function M:getStageCfgList()
    return self.stageSettings
end

M:init()
return M
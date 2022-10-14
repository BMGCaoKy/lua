
local editorSetting = require "editor.setting"
local cjson = require "cjson"
local globalSetting = L("globalSetting", {})
local modName = "global"

local function deletePosFunc(positions, mapName)
    for i, pos in pairs(positions or {}) do
        if pos.map == mapName and mapName then
            positions[i] = nil
        end
    end
end

local function deleteWorldRelatedwithPos(self, mapName)
    local startPos = self:getStartPos()
    local revivePos = self:getRevivePos()
    deletePosFunc(startPos, mapName)
    deletePosFunc(revivePos, mapName)
    if startPos and not next(startPos) then
        startPos = nil
    end 
    if revivePos and not next(revivePos) then
        revivePos = nil
    end
    self:saveStartPos(startPos)
    self:saveRevivePos(revivePos)
end

local function deleteTeamRelatedwithPos(self, mapName)
    local teams  = Lib.copy(self:getTeamMsg())

    local deleteBedFunc = function(bed)
        if bed and bed.pos and bed.pos.map == mapName then
            bed.pos = nil
        end
    end

    for id, team in ipairs(teams or {}) do
        local rebirthPos = team.rebirthPos
        local startPos = team.startPos
        deletePosFunc(rebirthPos, mapName)
        deletePosFunc(startPos, mapName)
        deleteBedFunc(team.bed)
        if rebirthPos and not next(rebirthPos) then
            team.rebirthPos = nil
        end
        if startPos and not next(startPos) then
            team.startPos = nil
        end
    end

    self:saveEditTeamMsg(teams, false)
end

function globalSetting:getValByKey(key)
    return editorSetting:getValueByKey(modName, nil, key)
end

function globalSetting:saveKey(key, val, isSave)
    editorSetting:saveValueByKey(modName, nil, key, val, isSave)
end

function globalSetting:deleteMap(mapName)
    deleteTeamRelatedwithPos(self, mapName)
    deleteWorldRelatedwithPos(self, mapName)
    
    local initPos = self:getInitPos()
    if initPos and initPos.map ==  mapName then
        self:saveInitPos()
    end

    editorSetting:saveCache("global")
end

function globalSetting:getTeamMsg()
    return Lib.copy(self:getValByKey("team"))
end

function globalSetting:saveEditTeamMaxPlayerNum(val, isSave)
    self:saveKey("teamMaxPlayerNum", val, isSave)
end

function globalSetting:getEditTeamMaxPlayerNum()
    return self:getValByKey("teamMaxPlayerNum")
end

function globalSetting:getEditTeamMsg()
    return Lib.copy(self:getValByKey("editorTeam"))
end

function globalSetting:saveEditTeamMsg(val, isSave)
	val = Lib.copy(val)
    if val and not next(val) then
        val = nil
    end
    self:saveKey("editorTeam", val, isSave)
    for index, teamData in pairs(val or {}) do
        teamData.id = index
    end
    if self:getGameTeamMode() then
        local tmpVar = Lib.copy(val)
        self:saveKey("team", tmpVar, isSave)
    end
end

function globalSetting:setTeamMode(enable)
    if enable then
        self:saveKey("team", Lib.copy(self:getValByKey("editorTeam")))
    else
        self:saveKey("team", nil)
    end
end

function globalSetting:getTestMap()
    return self:getValByKey("testMap")
end

function globalSetting:saveTestMap(val, isSave)
    return self:saveKey("testMap", val, isSave)
end

function globalSetting:getInitPos()
    return self:getValByKey("initPos")
end

function globalSetting:getShowScoreInfoMode()
    return self:getValByKey("showGameInfoMode")
end

function globalSetting:setShowScoreInfoMode(value)
    self:saveKey("showGameInfoMode", value)
end

function globalSetting:saveInitPos(val, isSave)
    if Player.CurPlayer and (not val or not next(val)) then
        local player = Player.CurPlayer
        local map = player.map
        local pos = player:getPosition()
        val = {
            default = true,
            map = map and map.name,
            x = pos.x,
            y = pos.y,
            z = pos.z
        }
    end
    return self:saveKey("initPos", val, isSave)
end

function globalSetting:saveDefaultMap(val, isSave)
    return self:saveKey("defaultMap", val, isSave)
end

function globalSetting:getStartPos()
    return self:getValByKey("startPos")
end

function globalSetting:saveStartPos(val, isSave)
    if val and not next(val) then
        val = nil
    end
    return self:saveKey("startPos", val, isSave)
end

function globalSetting:getRevivePos()
    return self:getValByKey("revivePos")
end

function globalSetting:saveRevivePos(val, isSave)
    if val and not next(val) then
        val = nil
    end
    return self:saveKey("revivePos", val, isSave)
end

function globalSetting:getTeammateHurt()
    return self:getValByKey("teammateHurt")
end

function globalSetting:saveTeammateHurt(val, isSave)
    return self:saveKey("teammateHurt", val, isSave)
end

function globalSetting:getMinPlayers()
    return self:getValByKey("minPlayers")
end

function globalSetting:saveMinPlayers(val, isSave)
    self:saveKey("minPlayers", val, isSave)
end

function globalSetting:getMaxPlayers()
    return self:getValByKey("maxPlayers")
end

function globalSetting:saveMaxPlayers(val, isSave)
    self:saveKey("maxPlayers", val, isSave)
end

function globalSetting:getRebirth()
    return editorSetting:getValueByKey(modName, nil, "rebirth")
end

function globalSetting:saveRebirth(val, isSave)
   editorSetting:saveValueByKey(modName, nil, "rebirth", val, isSave)
end

function globalSetting:getEnableTwiceJump()
    return self:getValByKey("enableTwiceJump")
end

function globalSetting:saveEnableTwiceJump(val, isSave)
    return self:saveKey("enableTwiceJump", val, isSave)
end

function globalSetting:getShowButtonShopName()
    return self:getValByKey("showButtonShopName")
end

function globalSetting:saveShowButtonShopName(val, isSave)
    return self:saveKey("showButtonShopName", val, isSave)
end

function globalSetting:getHideItemBar()
    return self:getValByKey("hideItemBar")
end

function globalSetting:saveHideItemBar(val, isSave)
    return self:saveKey("hideItemBar", val, isSave)
end

function globalSetting:saveGameTeamMode(val, isSave)
    if val then
        self:saveKey("team", Lib.copy(self:getValByKey("editorTeam")))
    else
        self:saveKey("team", nil)
    end
    return self:saveKey("gameTeamMode", val, isSave)
end

function globalSetting:getGameTeamMode()
    local team = self:getValByKey("team")
    local editorTeam = self:getValByKey("editorTeam")
    if team and #team > 0 then
        if not editorTeam then
            self:saveKey("editorTeam", Lib.copy(team))
        end
        return true
    end
    return self:getValByKey("gameTeamMode")
end

function globalSetting:getIsThirdView()
    return self:getValByKey("isThirdView")
end

function globalSetting:saveIsThirdView(val, isSave)
    return self:saveKey("isThirdView", val, isSave)
end

function globalSetting:saveIsUseNewScreenShot(val, isSave)
    return self:saveKey("isUseNewScreenShot", val, isSave)
end

function globalSetting:getViewMode()
    local cameraCfg = self:getValByKey("cameraCfg")
    local viewModeConfig = cameraCfg.viewModeConfig[cameraCfg.defaultView + 1] or {}
    local viewModeCfg = {
        selectViewBtn = cameraCfg.selectViewBtn or 1,
        defaultPitch = cameraCfg.defaultPitch or 0,
        distance = viewModeConfig.distance or 4.5,
        lockSlideScreen = not viewModeConfig.lockSlideScreen -- 此处让人迷惑，viewModeConfig.lockSlideScreen读的是配置是否可滑动，写的却是是否锁定？？？？
    }
    return viewModeCfg
end

function globalSetting:saveViewMode(val, topViewCfg, isSave)
    local cameraCfg = self:getValByKey("cameraCfg")
    if not cameraCfg then
        cameraCfg = {}
    end

    local function setTopViewCfg(topViewCfg)
        local viewModeIndex = 4
        if not topViewCfg then
            topViewCfg = {}
        end
        cameraCfg.viewModeConfig[viewModeIndex] = cameraCfg.viewModeConfig[viewModeIndex] or {}
        cameraCfg.defaultPitch = topViewCfg.defaultPitch or 0
        cameraCfg.viewModeConfig[viewModeIndex].distance = topViewCfg.distance or 4.5
        cameraCfg.viewModeConfig[viewModeIndex].lockSlideScreen = topViewCfg.lockSlideScreen==false
    end

    if val == 1 then
        cameraCfg.canSwitchView = true
        cameraCfg.defaultView = 1
    else
        cameraCfg.canSwitchView = false
        cameraCfg.defaultView = 3
    end
    topViewCfg = (val == 3 and topViewCfg) or nil
    setTopViewCfg(topViewCfg)
    cameraCfg.selectViewBtn = val
    return self:saveKey("cameraCfg", cameraCfg, isSave)
end


function globalSetting:getEnableTwiceJump()
    return self:getValByKey("enableTwiceJump")
end

function globalSetting:saveEnableTwiceJump(val, isSave)
    return self:saveKey("enableTwiceJump", val, isSave)
end

function globalSetting:getBasicEquip()
    return self:getValByKey("basicEquip")
end

function globalSetting:saveBasicEquip(val, isSave)
    return self:saveKey("basicEquip", val, isSave)
end

function globalSetting:getItemDropOnDie()
    return self:getValByKey("itemDropOnDie")
end

function globalSetting:saveItemDropOnDie(val, isSave)
    return self:saveKey("itemDropOnDie", val, isSave)
end

function globalSetting:getKillReward()
    return self:getValByKey("killReward")
end

function globalSetting:saveKillReward(val, isSave)
    return self:saveKey("killReward", val, isSave)
end

function globalSetting:getBedBreakReward()
    return self:getValByKey("bedBreakReward")
end

function globalSetting:saveBedBreakReward(val, isSave)
    return self:saveKey("bedBreakReward", val, isSave)
end

function globalSetting:getMerchantGroup()
    return self:getValByKey("merchantGroup")
end

function globalSetting:saveMerchantGroup(val, isSave)
    return self:saveKey("merchantGroup", val, isSave)
end

function globalSetting:getGameOverCondition()
    return self:getValByKey("gameOverCondition")
end

function globalSetting:saveGameOverCondition(val, isSave)
    return self:saveKey("gameOverCondition", val, isSave)
end

function globalSetting:getBagSelectItemStatus()
    return self:getValByKey("bagSelectItemStatus")
end

function globalSetting:saveBagSelectItemStatus(val)
    return self:saveKey("bagSelectItemStatus", val)
end

function globalSetting:save()
    editorSetting:saveCache(modName)
    Lib.emitEvent(Event.EVENT_TEAM_SETTING_CHANGE)
end

function globalSetting:clearData()
    editorSetting:clearData(modName)
    Lib.emitEvent(Event.EVENT_TEAM_SETTING_CHANGE)
end

function globalSetting:getTeamColorList()
    local teamColorList = Clientsetting.getData("teamColorList") or {"red", "green", "yellow" , "blue"}
    return teamColorList
end

function globalSetting:actorsIconData(actorName)
    local actorList = Clientsetting.getData("selectActorList") or {}
    local actorsIconData = {}
    actorsIconData["myplugin/bed"] = {
        icon = "set:setting_global.json image:bed.png",
        name = "actor.name.bed"
    }
    actorsIconData["myplugin/egg"] = {
        icon = "set:setting_global.json image:agg.png",
        name = "actor.name.egg"
    }
    for _, actor in ipairs(actorList or {}) do
        actorsIconData[actor.actor] = actor
    end
    return actorName and actorsIconData[actorName] or actorsIconData
end

local characterUICfg = {
    ["tabName"] = "gui_main_left_tab_name_role",
    ["lookOtherShow"] = true,
    ["titleName"] = "gui_main_title_name_role",
    ["openWindow"] = "character_panel",
    ["entityType"] = "ENTITY_INTO_TYPE_PLAYER"
}
local compositeUICfg = {
    ["tabName"] = "gui_player_composite",
    ["lookOtherShow"] = false,
    ["openWindow"] = "compositeUI",
    ["titleName"] = "gui_player_composite"
}
local unlimitUICfg = {
    ["tabName"] = "gui_player_unlimitedResources",
    ["lookOtherShow"] = false,
    ["openWindow"] = "unlimitedResources",
    ["titleName"] = "gui_player_unlimitedResources"
}

local function modifyUICfg(self, val, uiKey, uiCfg)
    local bagMainUi = self:getValByKey("bagMainUi") or {}
    local Iter = false
    local haveCharacter = false
    for k, v in pairs(bagMainUi) do
        if v.openWindow == uiKey then
            Iter = k
        end
        if v.openWindow == "character_panel" then
            haveCharacter = true
        end
    end
    if not haveCharacter then
        bagMainUi[#bagMainUi + 1] = characterUICfg
    end
    if val and not Iter then
        bagMainUi[#bagMainUi + 1] = uiCfg
        self:saveKey("bagMainUi", bagMainUi)
    elseif not val and Iter then
        table.remove(bagMainUi, Iter)
        self:saveKey("bagMainUi", bagMainUi)
    end
end

function globalSetting:saveResourcesMod(val)
    self:saveKey("resourcesMod", val)
    local unlimit = val == "unlimited"
    self:saveKey("unlimitedRes", unlimit)
    modifyUICfg(self, unlimit, "unlimitedResources", unlimitUICfg)
end

function globalSetting:getCompositeEnable()
    return self:getValByKey("compositeEnable")
end

function globalSetting:saveCompositeEnable(val)
    self:saveKey("compositeEnable", val)
    modifyUICfg(self, val, "compositeUI", compositeUICfg)
end

function globalSetting:onGamePlayerNumberChanged(key)
    if key == "teams" then --队伍数修改，修改最大人数
        local teamInfo = globalSetting:getTeamMsg()
        local teamMaxPlayers = 0
        for i,v in pairs(teamInfo or {}) do
            teamMaxPlayers = teamMaxPlayers + (v.memberLimit or 0)
        end
        if teamMaxPlayers > 0 then
            globalSetting:saveMaxPlayers(teamMaxPlayers)
        end
    end
    
    if key == "maxPlayers" or key == "minPlayers" or key == "teams" then --判断最小人是否大于最大人数
        local oldMin = globalSetting:getMinPlayers()
        local curMax = globalSetting:getMaxPlayers()
        if oldMin > curMax then
            globalSetting:saveMinPlayers(curMax)
        end
    end
end

function globalSetting:checkBindMonster(latestShopFlag)
    local shopData = self:getMerchantGroup()
    local latestBindMonsters = shopData[latestShopFlag].bindMonsters
    for shopFlag, shopCfg in pairs(shopData) do
        if shopFlag == latestShopFlag then
            goto continue
        end
        local monsters = shopCfg.bindMonsters
        for key in pairs(monsters) do
            if latestBindMonsters[key] then
                monsters[key] = nil
            end
        end
        ::continue::
    end
    self:saveMerchantGroup(shopData)
end

RETURN(globalSetting)

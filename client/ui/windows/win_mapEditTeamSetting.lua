local global_setting = require "editor.setting.global_setting"
local entity_obj = require "editor.entity_obj"
local data_state = require "editor.dataState"
local teamMsg = nil
local MAX_COUNT = 1
local lastBtn = nil
local enumColor = {"RED", "GREEN", "YELLOW", "BLUE"}

local itemIndexImageSize = {{27 * 0.85, 50 * 0.85},
                            {40 * 0.85, 50 * 0.85},
                            {39 * 0.85, 50 * 0.85},
                            {41 * 0.85, 50 * 0.85},
                            {40 * 0.85, 50 * 0.85}}

local function addPos(tPos, index, value)
    local tPos = tPos
    tPos[index] = value
end

local function delPos(tPos, index)
    local tPos = tPos
    tPos[index] = nil
end

local function getTableLen(tb)
    local len = 0
    for _, v in pairs(tb or {}) do
        if v then
            len = len + 1
        end
    end
    return len
end

local function nextBtnIndex(tPos)
    local tPos = tPos
    local rtn = 0
    local firstNil = 0
    for i = 1, MAX_COUNT do
        if rtn < i and tPos[i] then
            rtn = i
        end
        if not tPos[i] and firstNil == 0 then
            firstNil = i
        end
    end
    if firstNil < rtn then
        return firstNil
    else
        return rtn + 1
    end
end

local function fetchBtn(index)
    local button =  GUIWindowManager.instance:CreateGUIWindow1("Button", "")
    button:SetText(index)
    button:SetHeight({0, 90})
    button:SetWidth({0, 90})
    local frame =  GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "frame")
    frame:SetVerticalAlignment(1)
    frame:SetHorizontalAlignment(1)
    frame:SetImage("set:setting_global.json image:bg_position_act.png")
    frame:SetHeight({0, 93})
    frame:SetWidth({0, 93})
    frame:SetTouchable(false)
    frame:SetVisible(false)
    button:AddChildWindow(frame)
    if not index then
        return button
    end
    local numImage =  GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "numImage")
    numImage:SetWidth({0, itemIndexImageSize[index][1]})
    numImage:SetHeight({0, itemIndexImageSize[index][2]})
    numImage:SetImage("set:map_edit_setCheckpointNumber.json image:"..index)
    numImage:SetTouchable(false)
    numImage:SetVerticalAlignment(1)
    numImage:SetHorizontalAlignment(1)
    button:AddChildWindow(numImage)
    return button
end

function M:init()
    WinBase.init(self, "teamSetting_edit.json")
    --refreshTeamData()
    self:initUIName()
    self:initUILayout()
    self:initUI()
    self:initPopWnd()
    self:updateUI()

    Lib.subscribeEvent("del_team", function(data, opType)
        self:updateUI()
    end)

    Lib.subscribeEvent(Event.EVENT_SAVE_POS, function(data, opType)
        self:updateData()
        if opType == 1 then
            local idx = data.data
            self:setBrithWnd(self.birthAddBtn, idx)
            self.data.startPos[idx] = data.pos
            self.data.startPos[idx].map = data_state.now_map_name
            global_setting:saveStartPos(self.data.startPos)
        elseif opType == 2 then
            local idx = data.data
            self:setRebrithWnd(self.rebrithAddBtn, idx)
            self.data.revivePos[idx] = data.pos
            self.data.revivePos[idx].map = data_state.now_map_name
            global_setting:saveRevivePos(self.data.revivePos)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_POINT_DEL, function(opType, idx)
        if opType == 7 then
            return
        end
        self:updateData()
        local data = {}
        if opType == 1 then
            data = self.data.startPos
        elseif opType == 2 then
            data = self.data.revivePos
        end
        data[idx] = nil
        local entity = entity_obj:getEntityByDeriveType(opType, idx, 0)
        if entity then
            local id = entity_obj:getIdByEntity(entity)
            entity_obj:delEntity(id)
        end
        local pointParent
        if opType == 1 then
            global_setting:saveStartPos(data)
            pointParent = self.brithWnd
        elseif opType == 2 then
            global_setting:saveRevivePos(data)
            pointParent = self.rebrithWnd
        end
        local count = pointParent:GetItemCount()
        local child
        for i = 0, count - 1 do
            local cell = pointParent:GetItem(i)
            if cell:data("index") == idx then
                child = i
            end
        end
        if not child then
            return
        end
        local itemWnd = pointParent:GetItem(child)
        pointParent:RemoveItem(itemWnd)
        lastBtn = nil
        if (getTableLen(data)) ~= MAX_COUNT - 1 then
            return
        end
        local btn = fetchBtn()
        btn:SetNormalImage("set:setting_global.json image:btn_add_equip_n.png")
        btn:SetPushedImage("set:setting_global.json image:btn_add_equip_a.png")
        self:subscribe(btn, UIEvent.EventButtonClick, function()
            self:updateData()
            local data = opType == 2 and self.data.revivePos or self.data.startPos
            local nextIndex = nextBtnIndex(data)
            if nextIndex == 0 then
                return
            end
            self:setPosPoint(opType, {idx = nextIndex, teamId = 0}, true)
        end)
        if opType == 1 then
            self.birthAddBtn = btn
            self.brithWnd:AddItem(self.birthAddBtn)
        elseif opType == 2 then
            self.rebrithAddBtn = btn
            self.rebrithWnd:AddItem(self.rebrithAddBtn)
        end
    end)

end

function M:initPopWnd()
    self.toolPopWnd = UI:openMultiInstanceWnd("mapEditPopWnd")

    self.toolPopWndBgBtn = self.toolPopWnd:child("popWndRoot-BgBtn")
    self.showSeePopWnd = self.toolPopWnd:child("Setting-Point-Brith-Show")
    
    self.toolPopRespawnView = self.showSeePopWnd:child("Setting-Point-Brith-Show-See")
    self.toolPopRespawnDel  = self.showSeePopWnd:child("Setting-Point-Brith-Show-Del")
    self.toolPopRespawnView:SetText(Lang:toText("win.map.global.setting.shop.tool.view"))
    self.toolPopRespawnDel:SetText(Lang:toText("win.map.global.setting.shop.tool.delete"))

    self:subscribe(self.toolPopRespawnDel, UIEvent.EventButtonClick, function()
        if not lastBtn and not UI:isOpen(self) then
            return
        end
        local idx = lastBtn:data("index")
        local id2
        self:updateData()
        local data
        local Type = lastBtn:data("type")
        if Type == "rebrith" then
            data = self.data.revivePos
            id2 = 2
        elseif Type == "brith" then
            data = self.data.startPos
            id2 = 1
        end
        data[idx] = nil
        local entity = entity_obj:getEntityByDeriveType(id2, idx, 0)
        if entity then
            local id = entity_obj:getIdByEntity(entity)
            entity_obj:delEntity(id)
        end
        if Type == "rebrith" then
            global_setting:saveRevivePos(data)
            self.rebrithWnd:RemoveItem(lastBtn)
        elseif Type == "brith" then
            global_setting:saveStartPos(data)
            self.brithWnd:RemoveItem(lastBtn)
        end

        if (getTableLen(data)) == MAX_COUNT - 1 then
            if Type == "rebrith" then
                self.rebrithAddBtn = fetchBtn()
                self.rebrithAddBtn:SetNormalImage("set:setting_global.json image:btn_add_equip_n.png")
                self.rebrithAddBtn:SetPushedImage("set:setting_global.json image:btn_add_equip_a.png")
                self:subscribe(self.rebrithAddBtn, UIEvent.EventButtonClick, function()
                    self:updateData()
                    local data = self.data.revivePos
                    local nextIndex = nextBtnIndex(data)
                    if nextIndex == 0 then
                        return
                    end
                    self:setPosPoint(2, {idx = nextIndex, teamId = 0}, true)
        
                end)
                self.rebrithWnd:AddItem(self.rebrithAddBtn)
            elseif Type == "brith" then
                self.birthAddBtn = fetchBtn()
                self.birthAddBtn:SetNormalImage("set:setting_global.json image:btn_add_equip_n.png")
                self.birthAddBtn:SetPushedImage("set:setting_global.json image:btn_add_equip_a.png")
                self:subscribe(self.birthAddBtn, UIEvent.EventButtonClick, function()
                    self:updateData()
                    local data = self.data.startPos
                    local nextIndex = nextBtnIndex(data)
                    if nextIndex == 0 then
                        return
                    end
                    self:setPosPoint(1, {idx = nextIndex, teamId = 0}, true)
                end)
                self.brithWnd:AddItem(self.birthAddBtn)
            end
        end
        self:setPopWndEnabled(false)
    end)

    self:subscribe(self.toolPopRespawnView, UIEvent.EventButtonClick, function()
        if not lastBtn and not UI:isOpen(self) then
            return
        end
        local idx = lastBtn:data("index")
        local id2
        self:updateData()
        local data
        local Type = lastBtn:data("type")
        if Type == "rebrith" then
            data = self.data.revivePos
            id2 = 2
        elseif Type == "brith" then
            data = self.data.startPos
            id2 = 1
        end
        local pos = {x = data[idx].x, y = data[idx].y, z = data[idx].z, map = data[idx].map}
        self:setPosPoint(id2, {idx = idx, pos = pos, teamId = 0}, false)
        self:setPopWndEnabled(false)
--todo
    end)

    self:setPopWndEnabled(false)
    
    self:subscribe(self.toolPopWndBgBtn, UIEvent.EventWindowTouchUp, function()
        self:setPopWndEnabled(false)
	end)

end

function M:setPopWndEnabled(isEnable)
    
    if isEnable then
        self:setPopWndPosition()
    end

    if lastBtn then
        lastBtn:child("frame"):SetVisible(isEnable)
    end
    self.toolPopWndBgBtn:SetEnabledRecursivly(isEnable)
    self.toolPopWndBgBtn:SetVisible(isEnable)

    self.showSeePopWnd:SetEnabledRecursivly(isEnable)
    self.showSeePopWnd:SetVisible(isEnable)

end

function M:setPopWndPosition()
    local pos = lastBtn:GetRenderArea()
    local posx = {[1] = 0, [2] = pos[1] + lastBtn:GetPixelSize().x + 17}
    local posy = {[1] = 0, [2] = pos[2]}
    if posx[2] >= 1000 then
        posx[2] = pos[1] - 247
    end
    
    self.showSeePopWnd:SetXPosition(posx)
    self.showSeePopWnd:SetYPosition(posy)
end

function M:initReBrithWnd()
    self:updateData()
    local revivePos = self.data.revivePos

    self.rebrithWnd:RemoveAllItems()
    self.rebrithWnd:SetMoveAble(false)
    self.rebrithWnd:SetAutoColumnCount(false)
    self.rebrithWnd:InitConfig(46, 0, 6)
    self.rebrithShow = false

    local gridPos = self.rebrithWnd:GetXPosition()
    local rebrithNum = 0
    for i, rebrithItem in pairs(revivePos) do 
        if not rebrithItem then
            return
        end
        rebrithNum = rebrithNum + 1
        local btn = fetchBtn(i)
        btn:SetNormalImage("set:setting_global.json image:bg_position_nor.png")
        btn:SetPushedImage("set:setting_global.json image:bg_position_nor.png")
        btn:setData("index", i)
        btn:setData("type", "rebrith")
        self:subscribe(btn, UIEvent.EventButtonClick, function()
            lastBtn = btn
            self:setPopWndEnabled(true)
        end)
        self.rebrithWnd:AddItem(btn)
    end
    if MAX_COUNT > rebrithNum then
        self.rebrithAddBtn = fetchBtn()
        self.rebrithAddBtn:SetNormalImage("set:setting_global.json image:btn_add_equip_n.png")
        self.rebrithAddBtn:SetPushedImage("set:setting_global.json image:btn_add_equip_a.png")
        self:subscribe(self.rebrithAddBtn, UIEvent.EventButtonClick, function()
            self:updateData()
            local revivePos = self.data.revivePos
            local nextIndex = nextBtnIndex(revivePos)
            if nextIndex == 0 then
                return
            end
            self:setPosPoint(2, {idx = nextIndex, teamId = 0}, true)
        end)
        self.rebrithWnd:AddItem(self.rebrithAddBtn)
     end
end

function M:setRebrithWnd(addBtn, nextIndex)
    if not addBtn then
        return
    end
    self.rebrithWnd:RemoveItem(addBtn)
    local gridPos = self.rebrithWnd:GetXPosition()
    local btn1 = fetchBtn(nextIndex)
    btn1:setData("index", nextIndex)
    btn1:setData("type", "rebrith")
    btn1:SetNormalImage("set:setting_global.json image:bg_position_nor.png")
    btn1:SetPushedImage("set:setting_global.json image:bg_position_nor.png")
    self:subscribe(btn1, UIEvent.EventButtonClick, function()
        lastBtn = btn1
        self:setPopWndEnabled(true)
    end)
    self.rebrithWnd:AddItem(btn1)
    if nextIndex < MAX_COUNT then
        self.rebrithWnd:AddItem(addBtn)
    end
end

function M:initBrithWnd()
    self:updateData()
    local startPos = self.data.startPos
    self.brithWnd:RemoveAllItems()
    self.brithWnd:SetMoveAble(false)
    self.brithWnd:SetAutoColumnCount(false)
    self.brithWnd:InitConfig(46, 0, 6)
    self.brithShow = false
    local gridPos = self.brithWnd:GetXPosition()
    local brithNum = 0
    for i, birthItem in pairs(startPos) do 
        if not birthItem then
            return
        end
        brithNum = brithNum + 1
        local btn = fetchBtn(i)
        btn:setData("index", i)
        btn:setData("type", "brith")
        btn:SetNormalImage("set:setting_global.json image:bg_position_nor.png")
        btn:SetPushedImage("set:setting_global.json image:bg_position_nor.png")
        self:subscribe(btn, UIEvent.EventButtonClick, function()
            lastBtn = btn
            self:setPopWndEnabled(true)
        end)
        self.brithWnd:AddItem(btn)
    end
    if MAX_COUNT > brithNum then
        self.birthAddBtn = fetchBtn()
        self.birthAddBtn:SetNormalImage("set:setting_global.json image:btn_add_equip_n.png")
        self.birthAddBtn:SetPushedImage("set:setting_global.json image:btn_add_equip_a.png")
        self:subscribe(self.birthAddBtn, UIEvent.EventButtonClick, function()
            self:updateData()
            local startPos = self.data.startPos
            local nextIndex = nextBtnIndex(startPos)
            if nextIndex == 0 then
                return
            end
            self:setPosPoint(1, {idx = nextIndex, teamId = 0}, true)
        end)
        self.brithWnd:AddItem(self.birthAddBtn)
    end
end

function M:setBrithWnd(addBtn, nextIndex)
    if not addBtn then
        return
    end
    self.brithWnd:RemoveItem(addBtn)
    local gridPos = self.brithWnd:GetXPosition()
    local btn1 = fetchBtn(nextIndex)
    btn1:setData("index", nextIndex)
    btn1:setData("type", "brith")
    btn1:SetNormalImage("set:setting_global.json image:bg_position_nor.png")
    btn1:SetPushedImage("set:setting_global.json image:bg_position_nor.png")
    self:subscribe(btn1, UIEvent.EventButtonClick, function()
        lastBtn = btn1
        self:setPopWndEnabled(true)
    end)
    self.brithWnd:AddItem(btn1)
    if nextIndex < MAX_COUNT then
        self.brithWnd:AddItem(addBtn)
    end
end

function M:setPosPoint(op, data, isShowPanel)
    if UI:isOpen("mapEditPositionSetting") then
        UI:getWnd("mapEditPositionSetting"):onOpen(op, data, isShowPanel)
    else
        UI:openWnd("mapEditPositionSetting", op, data, isShowPanel, false, true)
    end
    Lib.emitEvent(Event.EVENT_HIDE_GLOBAL_SETTING, true, self.opType)
end

function M:controlTeamUI(isShow)
    self.teamWnd:SetVisible(isShow)
    self.teamPointWnd:SetVisible(not isShow)
    self.teamNumWnd:SetVisible(isShow)
end

function M:onClose()
    lastBtn = nil
end

function M:onOpen()
    self:updateUI()
end

function M:deleteTeamCorrelation()
    self.deleteTeam = false
    entity_obj:allEntityCmd("cehckTeamCorrelation", function(entity)
        return true
    end)
end

function M:saveData()
    if self.deleteTeam then
        self:deleteTeamCorrelation()
    end
end

function M:cancelSave()
    self.deleteTeam = false
end

function M:onReload(reloadArg)

end

function M:initUIName()
    self.detailTeamWnd = self:child("Setting-Team-Detail")
    self.teamNumWnd = self:child("Setting-Num")
    self.teamAttackWnd = self:child("Setting-Team-Layout")
    self.teamWnd = self:child("Setting-Team")
    self.teamPointWnd = self:child("Setting-Point")
    self.maxPlayerWnd = self:child("Setting-Point-MaXPlayer")
    self.rebrithWnd = self:child("Setting-Point-Rebrith-Grid")
    self.brithWnd = self:child("Setting-Point-Born-Grid")
    self.teamModeBtn = self:child("Setting-modeBtn")
    self.personModeBtn = self:child("Setting-modeBtn_2")
end

function M:updateData()
    local data = {}
    self.data = {}
    data.msg = global_setting:getEditTeamMsg() or {}
    data.teamCount = #data.msg
    data.teamMateHurt = global_setting:getTeammateHurt()
    data.maxPlayer = global_setting:getMaxPlayers()
    data.revivePos = global_setting:getRevivePos() or {}
    data.startPos = global_setting:getStartPos() or {}
    data.gameTeamMode = global_setting:getGameTeamMode()
    self.data = data
end

function M:checkSameColor()
    local hasColorMap = {}
    for _, v in pairs(enumColor) do
        hasColorMap[v] = false
    end
    for _, teamData in pairs(self.data.msg) do
        local color = teamData.color
        if hasColorMap[color] then
            for _, v in pairs(enumColor) do
                if not hasColorMap[v] then
                    teamData.color = v
                    hasColorMap[v] = true
                    break
                end 
            end
        else
            hasColorMap[color] = true
        end
    end
end

function M:setTeamCount(count)
    self:updateData()
    local curTeamCount = self.data.teamCount
    if curTeamCount > count then
        local function cancelFun()
            self.sliderWnd:invoke("setUIValue", curTeamCount)
        end
        local function sureFun()
            for i = curTeamCount, count + 1, -1 do
                table.remove(self.data.msg, i)
                entity_obj:delEntityByDeriveType(3, i)
                entity_obj:delEntityByDeriveType(4, i)
                entity_obj:delEntityByDeriveType(5, i)
            end
            global_setting:saveEditTeamMsg(self.data.msg, false)
        end
        self.tipWnd = UI:openWnd("mapEditTeamSettingTip", sureFun, cancelFun, 
            Lang:toText("win.map.global.setting.team.setting.tip")
        )
        self.tipWnd:switchBtnPosition()
    else
        for i = curTeamCount + 1, count do
            table.insert(self.data.msg, Clientsetting.getTeamTemplate())
            self.data.msg[i].id = i
        end
        self:checkSameColor()
        global_setting:saveEditTeamMsg(self.data.msg, false) 
    end
    global_setting:onGamePlayerNumberChanged("teams")
end

function M:getMaxPlayer()
    return self.data.maxPlayer
end

function M:getGameTeamMode()
    return self.data.gameTeamMode
end

function M:checkMaxPlayerNum(value)
    if not value then
        return
    end
    local gameSettingWnd = UI:getWnd("mapEditGameSetting")
    local minPlayerNum
    if gameSettingWnd and gameSettingWnd:getMinPlayers() then
        minPlayerNum = gameSettingWnd:getMinPlayers()
    else
        minPlayerNum = global_setting:getMinPlayers()
    end
    if value < minPlayerNum then
        self.sliderWnd1:invoke("setUIValue", minPlayerNum)
    else
        minPlayerNum = value
    end
    self.data.maxPlayer = minPlayerNum
end

function M:initUILayout()
    self:updateData()
    self.sliderWnd = UILib.createSlider({value = self.data.teamCount, index = 10, listenType = "onFinishTextChange"}, function(value, isInfinity) 
        self:setTeamCount(value)
    end)
    self.sliderWnd:SetHeight({0, 44}) 
    self.sliderWnd:SetWidth({0, 897})
    self.teamNumWnd:AddChildWindow(self.sliderWnd)

    self.offOnWnd = UILib.createSwitch({
        index = 21,
        value = self.data.teamMateHurt
    }, function(status)
        global_setting:saveTeammateHurt(status, false)
    end)
    self.teamAttackWnd:AddChildWindow(self.offOnWnd)

    self.sliderWnd1 = UILib.createSlider({value = self.data.maxPlayer, index = 11, listenType = "onFinishTextChange"}, function(value)
        self:checkMaxPlayerNum(value)
        global_setting:saveMaxPlayers(self.data.maxPlayer, false)
        global_setting:onGamePlayerNumberChanged("maxPlayers")
    end)
    self.sliderWnd1:SetHeight({0, 40})
    self.maxPlayerWnd:AddChildWindow(self.sliderWnd1)
end


function M:updateUI()
    self:updateGameModeUI()
    self:updateTeamUI()
end

function M:updateGameModeUI()
    self:updateData()
    local color1 = {99/255, 100/255, 106/255, 1}
    local color2 = {174/255, 184/255, 183/255, 1}
    local isChoseTeam = self.data.gameTeamMode
    self.teamModeBtn:SetSelected(isChoseTeam)
    self.personModeBtn:SetSelected(not isChoseTeam)
    self:child("Setting-modeText"):SetTextColor(isChoseTeam and color1 or color2)
    self:child("Setting-modeText_3"):SetTextColor(isChoseTeam and color2 or color1)
    self:controlTeamUI(isChoseTeam)
    if not self:getGameTeamMode() then
        self:checkMaxPlayerNum(self.data.maxPlayer)
    end
end

function M:updateTeamUI()
    local teamCount = self.data.teamCount
    self.sliderWnd:invoke("setUIValue", teamCount)
    self.offOnWnd:child("Offon-CheckBox"):SetCheckedNoEvent(self.data.teamMateHurt)--checkbox 
    self:initReBrithWnd()--rebrith num
    self:initBrithWnd()--brith num
end

function M:switchGameTeamMode(isTeam)
    if isTeam then
        global_setting:saveGameTeamMode(true)
        self:updateData()
        self:updateGameModeUI()
        local teamCount = self.data.teamCount
        if teamCount == 0 then
            self.sliderWnd:invoke("setUIValue", 1)
            self:setTeamCount(1)
        end 
    else
        global_setting:saveGameTeamMode(false)
        self:updateData()
        self:updateGameModeUI()
    end
end

function M:initUI()
    self:child("Setting-Point-Rebrith-Text"):SetText(Lang:toText("win.map.global.setting.team.rebrith"))
    self:child("Setting-Point-Born-Text"):SetText(Lang:toText("win.map.global.setting.team.born"))
    self:child("Setting-Team-Text"):setTextAutolinefeed(Lang:toText("win.map.global.setting.team.details"))
    self:child("Setting-Team-Text"):SetWordWrap(true)
    self:child("Setting-Team-Detail"):SetText(Lang:toText("win.map.global.setting.team.details.set"))

    self:child("Setting-Point-Born-Text_1"):SetText(Lang:toText("win.team.game.mode"))
    self:child("Setting-modeText"):SetText(Lang:toText("win.team.game.mode.team"))
    self:child("Setting-modeText_3"):SetText(Lang:toText("win.team.game.mode.person"))

    self:subscribe(self.teamModeBtn, UIEvent.EventWindowTouchUp, function()
        self:switchGameTeamMode(true)
    end)

    self:subscribe(self.personModeBtn, UIEvent.EventWindowTouchUp, function()
        self:switchGameTeamMode(false)
    end)

    self:subscribe(self.detailTeamWnd, UIEvent.EventButtonClick, function()
        CGame.instance:onEditorDataReport("click_global_setting_team_settings_details", "")
        self:updateData()
        if not (self.data.teamCount > 0) then
            return
        end 
        if UI:isOpen("mapEditTeamDetail") then
            UI:onClose("mapEditTeamDetail")
        end
        UI:openWnd("mapEditTeamDetail", self.data.teamCount)
    end)
end

return M
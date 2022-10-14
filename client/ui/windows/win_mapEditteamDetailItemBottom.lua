local global_setting = require "editor.setting.global_setting"
local entity_obj = require "editor.entity_obj"
local data_state = require "editor.dataState"
local temaMsg = {}
local color = nil

function M:init()
    WinBase.init(self, "teamDetailItemBottom_edit.json")

    self:initPopWnd()

    self.selectIndex = 1
    self.bornBtn = self:child("teamDetailItem-Born-Button")
    self.bornMoreBtn = self:child("teamDetailItem-Born-More")
    self.bornFrame = self:child("teamDetailItem-Born-Frame")

    self.resurrectionBtn = self:child("teamDetailItem-Resurrection-Button")
    self.resurrectionMoreBtn = self:child("teamDetailItem-Resurrection-More")
    self.resurrectionFrame = self:child("teamDetailItem-Resurrection-Frame")

    self.addSwitchLayout = self:child("teamDetailItem-Add-SwitchLayout")
    self.addAgg = self:child("teamDetailItem-Add-Agg")
    self.addAggFrame = self:child("teamDetailItem-Add-Agg-Frame")
    self.addAggSelect = self:child("teamDetailItem-Add-Agg-Select")
    self.addBad = self:child("teamDetailItem-Add-Bad")
    self.addBadFrame = self:child("teamDetailItem-Add-Bad-Frame")
    self.addBadSelect = self:child("teamDetailItem-Add-Bad-Select")
    self.gotoLay = self:child("teamDetailItem-Add-Lay")
    self.gotoSee = self:child("teamDetailItem-Add-See")

    if World.Lang == "ru" then
        self.bornBtn:SetWidth({0, 240})
        self.gotoLay:SetWidth({0, 240})
        self.resurrectionBtn:SetWidth({0, 200})
    end

    self:child("teamDetailItem-Born-Text"):setTextAutolinefeed(Lang:toText("win.map.global.setting.team.setting.born"))
    self:child("teamDetailItem-Resurrection-Text"):setTextAutolinefeed(Lang:toText("win.map.global.setting.team.setting.rebrith"))
    self:child("teamDetailItem-Born-Button-Text"):SetText(Lang:toText("win.map.global.setting.team.setting.place.setting"))
    self:child("teamDetailItem-Resurrection-Button-Text"):SetText(Lang:toText("win.map.global.setting.team.setting.place.setting"))
    self:child("teamDetailItem-Born-More-Text"):SetText(Lang:toText("win.map.global.setting.team.setting.place"))
    self:child("teamDetailItem-Resurrection-More-Text"):SetText(Lang:toText("win.map.global.setting.team.setting.place"))
    self:child("teamDetailItem-Add-Lay-Text"):SetText(Lang:toText("win.map.global.setting.team.setting.place.setting"))
    self:child("teamDetailItem-Add-See-Text"):SetText(Lang:toText("win.map.global.setting.team.setting.place"))

    self:initTeamBorn()
    self:initTeamResurrection()
    self:initTeamAddAggOrBad()

    Lib.subscribeEvent(Event.EVENT_SAVE_POS, function(data, opType, ry)
        if opType == 3 then
            self:switchBornState(true)
            temaMsg[self.selectIndex].startPos = temaMsg[self.selectIndex].startPos or {}
            temaMsg[self.selectIndex].startPos[1] = data.pos
            temaMsg[self.selectIndex].startPos[1].map = data_state.now_map_name
        elseif opType == 4 then
            self:switchResurrectionState(true)
            temaMsg[self.selectIndex].rebirthPos = temaMsg[self.selectIndex].rebirthPos or {}
            temaMsg[self.selectIndex].rebirthPos[1] = data.pos
            temaMsg[self.selectIndex].rebirthPos[1].map = data_state.now_map_name
        elseif opType == 5 or opType == 6 then
            self:switchLayState(true)
            if opType == 5 then
                temaMsg[self.selectIndex].bed.entity = "myplugin/bed"
            else
                temaMsg[self.selectIndex].bed.entity = "myplugin/egg"
            end
            temaMsg[self.selectIndex].bed.pos = data.pos
            temaMsg[self.selectIndex].bed.pos.map = data_state.now_map_name
            temaMsg[self.selectIndex].bed.ry =data.ry
        end
    end)

     Lib.subscribeEvent(Event.EVENT_POINT_DEL, function(opType)
        if opType == 3 then
            self:switchBornState(false)
            temaMsg[self.selectIndex].startPos = nil
            entity_obj:delEntityByDeriveType(opType, self.selectIndex)
        elseif opType == 4 then
            self:switchResurrectionState(false)
            temaMsg[self.selectIndex].rebirthPos[1] = nil
            entity_obj:delEntityByDeriveType(opType, self.selectIndex)
        elseif opType == 5 or opType == 6 then
            temaMsg[self.selectIndex].bed.pos = {}
            temaMsg[self.selectIndex].bed.ry = 0
            self:switchLayState(false)
            entity_obj:delEntityByDeriveType(opType, self.selectIndex)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_SETTING_ENTITY_MODEL, function(entityModel)
        temaMsg[self.selectIndex].bed.entity = entityModel
        if entityModel == "myplugin/bed" then
            self:isSelectAgg(false)
        else
            self:isSelectAgg(true)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_CHANGE_TEAM_COLOR, function(color)
        color = color
    end)

end

function M:initPopWnd()
    self.toolPopWnd = UI:openMultiInstanceWnd("mapEditPopWnd")

    self.toolPopWndBgBtn = self.toolPopWnd:child("popWndRoot-BgBtn")
    
    self.bornTool = self.toolPopWnd:child("teamDetailItem-Born-Tool")
    self.bornDeleteBtn = self.toolPopWnd:child("teamDetailItem-Born-Delete")
    self.bornDeleteBtn:child("teamDetailItem-Born-Delete-Text"):SetText(Lang:toText("win.map.global.setting.pop.del"))
    self.bornViewBtn = self.toolPopWnd:child("teamDetailItem-Born-View")
    self.bornViewBtn:child("teamDetailItem-Born-View-Text"):SetText(Lang:toText("win.map.global.setting.pop.check"))

    self.resurrectionTool = self.toolPopWnd:child("teamDetailItem-Resurrection-Tool")
    self.resurrectionDeleteBtn = self.toolPopWnd:child("teamDetailItem-Resurrection-Delete")
    self.resurrectionDeleteBtn:child("teamDetailItem-Resurrection-Delete-Text"):SetText(Lang:toText("win.map.global.setting.pop.del"))
    self.resurrectionViewBtn = self.toolPopWnd:child("teamDetailItem-Resurrection-View")
    self.resurrectionViewBtn:child("teamDetailItem-Resurrection-View-Text"):SetText(Lang:toText("win.map.global.setting.pop.check"))

    self:setPopWndEnabled(false)
    
    self:subscribe(self.toolPopWndBgBtn, UIEvent.EventWindowTouchUp, function()
        self:setPopWndEnabled(false, "born")
        self:setPopWndEnabled(false, "resurrection")
	end)

end

function M:setPopWndEnabled(isEnable, typeName)
    
    if isEnable then
        self:setPopWndPosition()
    end

    self.toolPopWndBgBtn:SetEnabledRecursivly(isEnable)
    self.toolPopWndBgBtn:SetVisible(isEnable)

    if typeName and typeName == "born" then
        self.bornFrame:SetVisible(isEnable)
        self.bornTool:SetEnabledRecursivly(isEnable)
        self.bornTool:SetVisible(isEnable)
    end

    if typeName and typeName == "resurrection" then
        self.resurrectionFrame:SetVisible(isEnable)
        self.resurrectionTool:SetEnabledRecursivly(isEnable)
        self.resurrectionTool:SetVisible(isEnable)
    end
end

function M:setPopWndPosition()
    local bornPos = self.bornFrame:GetRenderArea()
    local bornPosx = {[1] = 0, [2] = bornPos[1] + self.bornFrame:GetPixelSize().x + 10}
    local bornPosy = {[1] = 0, [2] = bornPos[2]}
    self.bornTool:SetXPosition(bornPosx)
    self.bornTool:SetYPosition(bornPosy)

    local resurrectionPos = self.resurrectionFrame:GetRenderArea()
    local resurrectionPosx = {[1] = 0, [2] = resurrectionPos[1] + self.bornFrame:GetPixelSize().x + 10}
    local resurrectionPosy = {[1] = 0, [2] = resurrectionPos[2]}
    self.resurrectionTool:SetXPosition(resurrectionPosx)
    self.resurrectionTool:SetYPosition(resurrectionPosy)
end

function M:initTeamBorn()

    self:subscribe(self.bornBtn, UIEvent.EventButtonClick, function()
        local startPos = temaMsg[self.selectIndex].startPos and temaMsg[self.selectIndex].startPos[1] or nil
        local pos = startPos and {x = startPos.x, y = startPos.y, z = startPos.z, map = startPos.map} or nil
        self:setPosPoint(3, {idx = self.selectIndex, pos = pos, teamId = self.selectIndex, tempColor = color or temaMsg[self.selectIndex].color}, true)
	end) 

    self:subscribe(self.bornMoreBtn, UIEvent.EventButtonClick, function()
        self:setPopWndEnabled(true, "born")
	end)

    self:subscribe(self.bornViewBtn, UIEvent.EventButtonClick, function()
        --todo
        self:setPopWndEnabled(false, "born")
        local startPos = temaMsg[self.selectIndex].startPos and temaMsg[self.selectIndex].startPos[1] or nil
        local pos = startPos and {x = startPos.x, y = startPos.y, z = startPos.z, map = startPos.map} or nil
        self:setPosPoint(3, {idx = self.selectIndex, pos = pos, teamId = self.selectIndex, tempColor = color or temaMsg[self.selectIndex].color}, false)
	end)

    self:subscribe(self.bornDeleteBtn, UIEvent.EventButtonClick, function()
        self:setPopWndEnabled(false, "born")
        self:switchBornState(false)
        temaMsg[self.selectIndex].startPos = nil
        entity_obj:delEntityByDeriveType(3, self.selectIndex)
	end)
end

function M:initTeamResurrection()

    self:subscribe(self.resurrectionBtn, UIEvent.EventButtonClick, function()
        local rebirthPos = temaMsg[self.selectIndex].rebirthPos and temaMsg[self.selectIndex].rebirthPos[1] or nil
        local pos = rebirthPos and {x = rebirthPos.x, y = rebirthPos.y, z = rebirthPos.z, map = rebirthPos.map} or nil
        self:setPosPoint(4, {idx = self.selectIndex, pos = pos, teamId = self.selectIndex, tempColor = color or temaMsg[self.selectIndex].color}, true) --暂时为4
	end) 

    self:subscribe(self.resurrectionMoreBtn, UIEvent.EventButtonClick, function()
        self:setPopWndEnabled(true, "resurrection")
	end)

    self:subscribe(self.resurrectionViewBtn, UIEvent.EventButtonClick, function()
        --todo
        self:setPopWndEnabled(false, "resurrection")
        local rebirthPos = temaMsg[self.selectIndex].rebirthPos and temaMsg[self.selectIndex].rebirthPos[1] or nil
        local pos = rebirthPos and {x = rebirthPos.x, y = rebirthPos.y, z = rebirthPos.z, map = rebirthPos.map} or nil
        self:setPosPoint(4, {idx = self.selectIndex, pos = pos, teamId = self.selectIndex, tempColor = color or temaMsg[self.selectIndex].color}, false) --暂时为4
	end)

    self:subscribe(self.resurrectionDeleteBtn, UIEvent.EventButtonClick, function()
        self:setPopWndEnabled(false, "resurrection")
        self:switchResurrectionState(false)
        temaMsg[self.selectIndex].rebirthPos[1] = nil
        entity_obj:delEntityByDeriveType(4, self.selectIndex)
	end)
end

function M:setPosPoint(op, data, isShowPanel)
    Lib.emitEvent(Event.EVENT_HIDE_GLOBAL_SETTING, true, self.opType, self.selectIndex)
    if UI:isOpen("mapEditPositionSetting") then
        UI:getWnd("mapEditPositionSetting"):onOpen(op, data, isShowPanel)
        return
    end
    UI:openWnd("mapEditPositionSetting", op, data, isShowPanel)
--    if isEmitEvent then
--        --Lib.emitEvent(Event.EVENT_SETTING_POS, pos)
--    end
end

function M:initTeamAddAggOrBad()
    
    self.addSwitch = UILib.createSwitch({
            index = 22,
            value = false
        }, function(status)
            temaMsg[self.selectIndex].bed.enable = status
            self:isOpenAddSwitch(status)
            entity_obj:delEntityByDeriveType(5, self.selectIndex)
        end)
    self.addSwitchLayout:AddChildWindow(self.addSwitch)

    self:subscribe(self.addBadFrame, UIEvent.EventWindowTouchUp, function()
        self:isSelectAgg(false)
        temaMsg[self.selectIndex].bed.entity = "myplugin/bed"
	end)

    self:subscribe(self.addAggFrame, UIEvent.EventWindowTouchUp, function()
        self:isSelectAgg(true)
        temaMsg[self.selectIndex].bed.entity = "myplugin/egg"
	end)

    self:subscribe(self.gotoLay, UIEvent.EventButtonClick, function()
        local isbed = self.addBadSelect:IsVisible()
        local isagg = self.addAggSelect:IsVisible()
        local bedPos = temaMsg[self.selectIndex].bed.pos
        local ry = temaMsg[self.selectIndex].bed.ry or 0
        local pos = bedPos and {x = bedPos.x, y = bedPos.y, z = bedPos.z, map = bedPos.map} or nil
        if isbed and (not isagg) then
            self:setPosPoint(5, {entity = "myplugin/bed", idx = 1, pos = pos, ry = ry, teamId = self.selectIndex, color = color or temaMsg[self.selectIndex].color}, true)
            --todo set bad
        elseif (not isbed) and isagg then
            self:setPosPoint(6, {entity = "myplugin/egg", idx = 1, pos = pos, ry = ry, teamId = self.selectIndex, color = color or temaMsg[self.selectIndex].color}, true)
            -- todo set agg
        end
    end)

    self:subscribe(self.gotoSee, UIEvent.EventButtonClick, function()
        local isbed = self.addBadSelect:IsVisible()
        local isagg = self.addAggSelect:IsVisible()
        local bedPos = temaMsg[self.selectIndex].bed.pos
        local ry = temaMsg[self.selectIndex].bed.ry or 0
        local pos = bedPos and {x = bedPos.x, y = bedPos.y, z = bedPos.z, map = bedPos.map} or nil
        if isbed and (not isagg) then
            self:setPosPoint(5, {entity = "myplugin/bed", idx = 1, pos = pos, ry = ry, teamId = self.selectIndex, color = color or temaMsg[self.selectIndex].color}, false)
            --todo set bad
        elseif (not isbed) and isagg then
            self:setPosPoint(6, {entity = "myplugin/egg", idx = 1, pos = pos, ry = ry, teamId = self.selectIndex, color = color or temaMsg[self.selectIndex].color}, false)
            -- todo set agg
        end
    end)

end

function M:isOpenAddSwitch(isOpend)
    self.addAgg:SetEnabled(isOpend)
    self.addAggFrame:SetEnabled(isOpend)
    self.addAggSelect:SetEnabled(isOpend)
    self.addBad:SetEnabled(isOpend)
    self.addBadFrame:SetEnabled(isOpend)
    self.addBadSelect:SetEnabled(isOpend)
    self.gotoLay:SetEnabled(isOpend)
    self.gotoSee:SetEnabled(isOpend)
    local flag = (not temaMsg[self.selectIndex].bed.pos) or (not next(temaMsg[self.selectIndex].bed.pos))
    self:switchLayState(not flag)
    temaMsg[self.selectIndex].bed.enable = isOpend
end

function M:isSelectAgg(isAgg, enable)
    self.isAgg = isAgg
    self.addAggSelect:SetVisible(isAgg)
    self.addBadSelect:SetVisible(not isAgg)
    temaMsg[self.selectIndex].bed.enable = enable or temaMsg[self.selectIndex].bed.enable
end

function M:isShowResurrectionTool(isShow)
    self.resurrectionTool:SetVisible(isShow)
    self.resurrectionFrame:SetVisible(isShow)
    self.resurrectionState = isShow
    Blockman.instance.gameSettings.isPopWindow = isShow or self.bornViewState
    Lib.emitEvent(Event.EVENT_POINT_STATE, isShow or self.bornViewState)
end

function M:switchLayState(isSetBorn)
    self.gotoLay:SetVisible(not isSetBorn)
    self.gotoSee:SetVisible(isSetBorn)
end

function M:switchResurrectionState(isSetResurrection)
    self.resurrectionBtn:SetVisible(not isSetResurrection)
    self.resurrectionMoreBtn:SetVisible(isSetResurrection)
end

function M:switchBornState(isSetBorn)
    self.bornBtn:SetVisible(not isSetBorn)
    self.bornMoreBtn:SetVisible(isSetBorn)
end

function M:isTextGray(Text, isGray)
    Text:SetEnabled(isGray)
    if isGray then
        Text:SetTextColor({174/255, 184/255, 183/255, 1})
    else
        Text:SetTextColor({99/255, 100/255, 106/255, 1})
    end
end

function M:refreshWnd()
    local team = temaMsg[self.selectIndex]
    local bed = team.bed
    if bed.enable then
        self.addSwitch:child("Offon-CheckBox"):SetCheckedNoEvent(true)
        self:isOpenAddSwitch(true)
    else
        self.addSwitch:child("Offon-CheckBox"):SetCheckedNoEvent(false)
        self:isOpenAddSwitch(false)
    end
    if bed.entity and bed.entity == "myplugin/bed" then
        self:isSelectAgg(false)
    elseif  bed.entity then
        self:isSelectAgg(true)
    end
    self:switchResurrectionState(team.rebirthPos and next(team.rebirthPos[1] or {}) and true or false)
    self:switchBornState(team.startPos and next(team.startPos[1] or {}) and true or false)

end

function M:onOpen(selectIndex, teamData)--接这里的数据时，找我(zhenwu)
    color = nil
    temaMsg = teamData
    self.selectIndex = selectIndex
    self:refreshWnd()
end

function M:onClose()

end

function M:onReload()

end

return M
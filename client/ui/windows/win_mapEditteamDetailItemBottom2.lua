local global_setting = require "editor.setting.global_setting"
local entity_obj = require "editor.entity_obj"
local data_state = require "editor.dataState"
local temaMsg = {}
local color = nil
local function fetchBtn(params)
    params = params or {}

    local button =  GUIWindowManager.instance:CreateGUIWindow1("Button", "")
    button:SetHeight({0, params.height or 90})
    button:SetWidth({0, params.width or 90})


    local bg =  GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "")
    bg:SetImage("set:setting_global.json image:bg_player_actor.png")
    bg:SetHeight({1, 0})
    bg:SetWidth({1, 0})
    bg:SetTouchable(false)
    bg:SetVisible(false)
    button:AddChildWindow(bg)


    local actor =  GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "")
    actor:SetHeight({0.8, 0})
    actor:SetWidth({0.8, 0})
    actor:SetTouchable(false)
    actor:SetVisible(false)
    actor:SetVerticalAlignment(1)
    actor:SetHorizontalAlignment(1)
    button:AddChildWindow(actor)

    local frame =  GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "frame")
    frame:SetVerticalAlignment(2)
    frame:SetHorizontalAlignment(2)
    frame:SetImage("set:setting_global.json image:btn_change_player_actor.png")
    frame:SetHeight({0, 48})
    frame:SetWidth({0, 48})
    frame:SetTouchable(false)
    frame:SetVisible(false)
    button:AddChildWindow(frame)
    local uiStyleFunc = function(cmd, value)
        if cmd == "openFrame" then
            frame:SetVisible(value)
        end
        if cmd == "setActorImage" then
            bg:SetVisible(true)
            actor:SetVisible(true)
            frame:SetVisible(true)
            actor:SetImage(value.icon)
            actor:SetHeight({0.8, 0})
            if value.height then
                actor:SetWidth({0.8 * value.width / value.height, 0})
            else
                actor:SetWidth({0.8, 0})
            end
        end

    end
    button:setData("uiStyleFunc", uiStyleFunc)
    return button
end

function M:getTeamInfo()
    return temaMsg
end

function M:init()
    WinBase.init(self, "teamDetailItemBottom_edit2.json")
    self:initUIName()
    self:initUIText()
    self:updateData()
    Lib.subscribeEvent(Event.EVENT_SAVE_POS, function(data, opType, ry)
        self:updateData()
        local tempPos = {x = data.pos.x, y = data.pos.y, z = data.pos.z}
        if opType == 3 then
            temaMsg[self.selectIndex].startPos = temaMsg[self.selectIndex].startPos or {}
            temaMsg[self.selectIndex].startPos[1] = tempPos
            temaMsg[self.selectIndex].startPos[1].map = data_state.now_map_name
        elseif opType == 4 then
            temaMsg[self.selectIndex].rebirthPos = temaMsg[self.selectIndex].rebirthPos or {}
            temaMsg[self.selectIndex].rebirthPos[1] = tempPos
            temaMsg[self.selectIndex].rebirthPos[1].map = data_state.now_map_name
        elseif opType == 5 or opType == 6 then
            temaMsg[self.selectIndex].bed.entity = data.entity
            temaMsg[self.selectIndex].bed.pos = tempPos
            temaMsg[self.selectIndex].bed.pos.map = data_state.now_map_name
            temaMsg[self.selectIndex].bed.ry = data.ry
            temaMsg[self.selectIndex].bed.enable = true
        end
        global_setting:saveEditTeamMsg(temaMsg)
        self:updateUI()
    end)

     Lib.subscribeEvent(Event.EVENT_POINT_DEL, function(opType)
        self:updateData()
        if opType == 3 then
            temaMsg[self.selectIndex].startPos = nil
            entity_obj:delEntityByDeriveType(opType, self.selectIndex)
        elseif opType == 4 then
            temaMsg[self.selectIndex].rebirthPos[1] = nil
            entity_obj:delEntityByDeriveType(opType, self.selectIndex)
        elseif opType == 5 or opType == 6 then
            temaMsg[self.selectIndex].bed.pos = {}
            temaMsg[self.selectIndex].bed.ry = 0
            entity_obj:delEntityByDeriveType(opType, self.selectIndex)
        end
        global_setting:saveEditTeamMsg(temaMsg)
        self:updateUI()
    end)

    self:subscribe(self.teamResBtn, UIEvent.EventButtonClick, function()
        UI:openWnd("mapEditBasicEquip", {
            teamIndex = self.selectIndex
        })
    end)
end

function M:initUIName()
    self.startPointLayout = self:child("teamDetailItem-addBtn")
    self.rebrithPointLayout = self:child("teamDetailItem-addBtn_1")
    self.basePointLayout = self:child("teamDetailItem-addBtn_1_5")
    self.teamResBtn = self:child("teamDetailItem-teamResBtn")
end

function M:initUIText()
    self:child("teamDetailItem-startPoint-text"):setTextAutolinefeed(Lang:toText("win.map.global.setting.team.setting.born"))
    self:child("teamDetailItem-startPoint-text_0"):setTextAutolinefeed(Lang:toText("win.map.global.setting.team.setting.rebrith"))
    self:child("teamDetailItem-teamWait_0_4"):setTextAutolinefeed(Lang:toText("win.map.global.setting.team.setting.base"))
    self:child("teamDetailItem-startPoint-text_0_4_0"):setTextAutolinefeed(Lang:toText("win.map.global.setting.player.tab.resource.set"))
    self:child("teamDetailItem-startPoint-text_0_4"):setTextAutolinefeed(Lang:toText("win.map.global.setting.team.setting.base"))
    self:child("teamDetailItem-startPoint-text_0_4_8"):setTextAutolinefeed(Lang:toText("win.map.global.setting.player.tab.quality.model.title"))
    self.teamResBtn:SetText(Lang:toText("block.die.drop.setting"))

end

function M:onOpen(selectIndex)--接这里的数据时，找我(zhenwu)
    color = nil
    self.selectIndex = selectIndex
    self:updateUI()
end

function M:updateData()
    temaMsg = global_setting:getEditTeamMsg() or {}
end

function M:updateUI()
    self:updateData()
    if not self.selectIndex then
        return
    end
    self:updateRebrithBtnUI()
    self:updateStartPosBtnUI()
    self:updateTeamBaseUI()
    self:updateActorBtnUI()
end
    
function M:setPosPoint(op, data, isShowPanel)
    Lib.emitEvent(Event.EVENT_HIDE_GLOBAL_SETTING, true, self.opType, self.selectIndex)
    if UI:isOpen("mapEditPositionSetting") then
        UI:getWnd("mapEditPositionSetting"):onOpen(op, data, isShowPanel)
        return
    end
    UI:openWnd("mapEditPositionSetting", op, data, isShowPanel)
end

function M:updatePointUI(layoutRoot, popLayout, showAddBtn, addFunction, clickFunction, uiStyleFunc, selectList, uiStyleSize)
    layoutRoot:CleanupChildren()
    local btn = fetchBtn(uiStyleSize)
    if showAddBtn then
        btn:SetNormalImage("set:setting_global.json image:btn_add_equip_n.png")
        btn:SetPushedImage("set:setting_global.json image:btn_add_equip_a.png")
        self:subscribe(btn, UIEvent.EventButtonClick, function()
            addFunction()
        end)
    else
        local selectList = selectList or {
            {
                text = "win.map.global.setting.pop.check",
            },
            {
                text = "win.map.global.setting.pop.del",
            }
        }
        btn:SetNormalImage("set:setting_global.json image:bg_position_nor.png")
        btn:SetPushedImage("set:setting_global.json image:bg_position_nor.png")
        if uiStyleFunc then
            uiStyleFunc(btn)
        end
        self:subscribe(btn, UIEvent.EventButtonClick, function()
            local pullDown = UIMgr:new_widget("pullDown")
            GUISystem.instance:GetRootWindow():AddChildWindow(pullDown)
            pullDown:SetLevel(1)
            self:setPopWndPos(popLayout, pullDown)
            pullDown:invoke("fillData", {
                selectList = selectList,
                backFunc = function(index)
                    clickFunction(index)
                    World.Timer(2, function()
                        pullDown:CleanupChildren()
                        GUISystem.instance:GetRootWindow():RemoveChildWindow1(pullDown)
                    end)
                end,
                showCheckUI = false,
                disableSelect = true
            })
        end)
    end
    layoutRoot:AddChildWindow(btn)
end

function M:setPopWndPos(layout, widget)
    local bornPos = layout:GetRenderArea()
    local bornPosx = {[1] = 0, [2] = bornPos[1]}
    local bornPosy = {[1] = 0, [2] = bornPos[2]}
    widget:SetArea(bornPosx, bornPosy, {0, bornPos[3] - bornPos[1]}, {0, bornPos[4] - bornPos[2]})
end

function M:saveData()
    global_setting:saveEditTeamMsg(temaMsg)
    self:updateUI()
end

function M:updateRebrithBtnUI()
    self.rebrithPointLayout:CleanupChildren()
    local dataList = temaMsg and temaMsg[self.selectIndex].rebirthPos or {}
    local showAddBtn = not dataList.pos and #dataList == 0
    self:updatePointUI(self.rebrithPointLayout, self:child("teamDetailItem-pop_3"), showAddBtn, 
    function()
        self:updateData()
        self:setPosPoint(4, {idx = self.selectIndex, teamId = self.selectIndex, tempColor = temaMsg[self.selectIndex].color}, true) --暂时为4
    end, function(index)
        if index == 1 then
            local rebirthPos = temaMsg[self.selectIndex].rebirthPos and temaMsg[self.selectIndex].rebirthPos[1] or nil
            local pos = rebirthPos and {x = rebirthPos.x, y = rebirthPos.y, z = rebirthPos.z, map = rebirthPos.map} or nil
            self:setPosPoint(4, {idx = self.selectIndex, pos = pos, teamId = self.selectIndex, tempColor = temaMsg[self.selectIndex].color}, false) --暂时为4
        else
            temaMsg[self.selectIndex].rebirthPos[1] = nil
            entity_obj:delEntityByDeriveType(4, self.selectIndex)
            self:saveData()
        end
    end)  
end

function M:updateStartPosBtnUI()
    local dataList = temaMsg and temaMsg[self.selectIndex].startPos or {}
    local showAddBtn = not dataList.pos and #dataList == 0
    self:updatePointUI(self.startPointLayout, self:child("teamDetailItem-pop"), showAddBtn,
    function()
        self:setPosPoint(3, {idx = self.selectIndex, teamId = self.selectIndex, tempColor = temaMsg[self.selectIndex].color}, true) --暂时为4
    end,function(index)
        self:updateData()
        if index == 1 then
            local startPos = temaMsg[self.selectIndex].startPos and temaMsg[self.selectIndex].startPos[1] or nil
            local pos = startPos and {x = startPos.x, y = startPos.y, z = startPos.z, map = startPos.map} or nil
            self:setPosPoint(3, {idx = self.selectIndex, pos = pos, teamId = self.selectIndex, tempColor = temaMsg[self.selectIndex].color}, false) --暂时为3
        else
            temaMsg[self.selectIndex].startPos[1] = nil
            entity_obj:delEntityByDeriveType(3, self.selectIndex)
            self:saveData()
        end
    end)
end

function M:updateTeamBaseUI()
    local dataList = temaMsg and temaMsg[self.selectIndex].bed or {}
    local showAddBtn = not dataList.enable


    local uiStyleFunc = function(btn)
        local func = btn:data("uiStyleFunc")
        func("setActorImage", global_setting:actorsIconData(dataList.entity))
    end

    self:updatePointUI(self.basePointLayout, self:child("teamDetailItem-pop_3_6"), showAddBtn,
    function()
        local data = temaMsg[self.selectIndex].bed or {}
        UI:openWnd("mapEditBaseSelect", function(name)
            self:setPosPoint(5, {entity = name, idx = 1, enable = true, teamId = self.selectIndex, color = color or temaMsg[self.selectIndex].color}, true)
        end, data.entity or "myplugin/bed")
    end, 
    function(index)
        self:updateData()
        if index == 1 then
            local data = temaMsg[self.selectIndex].bed or {}
            UI:openWnd("mapEditBaseSelect", function(name)
                self:setPosPoint(5, {entity = name, idx = 1, enable = true, teamId = self.selectIndex, color = color or temaMsg[self.selectIndex].color}, true)
                end, data.entity or "myplugin/bed")
        elseif index == 2 then
            local data = temaMsg[self.selectIndex].bed
            local bedPos = data.pos
            local ry = data.ry or 0
            local pos = bedPos and {x = bedPos.x, y = bedPos.y, z = bedPos.z, map = bedPos.map} or nil
            self:setPosPoint(5, {entity = data.entity, idx = 1, pos = pos, ry = ry, teamId = self.selectIndex, color = color or temaMsg[self.selectIndex].color}, true)
        else
            local bedTab = temaMsg[self.selectIndex].bed
            if bedTab then
                bedTab.enable = false
            end
            entity_obj:delEntityByDeriveType(5, self.selectIndex)
            self:saveData()
        end
    end,
    uiStyleFunc,
    {
        {
            text = "win.map.global.setting.actor.change",
        },
        {
            text = "win.map.global.setting.pop.check",
        },
        {
            text = "win.map.global.setting.pop.del",
        }
    }, {width = 140, height = 140})
end


function M:updateActorBtnUI()
    local actorName = temaMsg and temaMsg[self.selectIndex].actorName
    self:child("teamDetailItem-addBtn_1_5_9"):CleanupChildren()
    local function choseActor()
        UI:openWnd("mapEditModleSetting", {selectedActor = actorName, backFunc = function(actorName)
            self:updateData()
            if actorName == "selfMode" then
                temaMsg[self.selectIndex].ignorePlayerSkin = false
            else
                temaMsg[self.selectIndex].ignorePlayerSkin = true
            end
            temaMsg[self.selectIndex].actorName = actorName
            self:saveData()
        end})
    end

    local btn = fetchBtn({width = 140, height = 140})
    if not actorName then
        btn:SetNormalImage("set:setting_global.json image:btn_add_equip_n.png")
        btn:SetPushedImage("set:setting_global.json image:btn_add_equip_a.png")
    else
        local func = btn:data("uiStyleFunc")
        func("setActorImage", global_setting:actorsIconData(actorName))
    end
    self:subscribe(btn, UIEvent.EventButtonClick, function()
        choseActor()
    end)
    self:child("teamDetailItem-addBtn_1_5_9"):AddChildWindow(btn)
end

return M
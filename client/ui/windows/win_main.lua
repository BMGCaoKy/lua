local setting = require "common.setting"
local guideFullName
local key2index = {}
local uiEffects = {}
local uiEffectTimers = {}

local worldCfg = World.cfg
local MAX_COUNT = worldCfg.handBagCap or 9
local isEditorEnvironment =  World.CurWorld.isEditorEnvironment
local isEditor =  World.CurWorld.isEditor

local misc = require "misc"
local now_nanoseconds = misc.now_nanoseconds
local function getTime()
    return now_nanoseconds() / 1000000
end

local function checkUIEffectView(self)
    local view = Blockman.instance:getCurrPersonView()
    self.uiEffectContent:SetVisible(view == 0)
end

local function ui_effect(self, value, add, time)
    local name = value.effect or value
    local function removeEffectView(name)
        local view = uiEffects[name]
        if view then
            self.uiEffectContent:RemoveChildWindow1(view)
            uiEffects[name] = nil
        end
        local timer = uiEffectTimers[name]
        if timer then
            timer()
            uiEffectTimers[name] = nil
        end
    end
    removeEffectView(name)
    if not add then
        return
    end
    local area = value.area or {{0, 0}, {0, 0}, {1, 0}, {1, 0}}
    local ui = GUIWindowManager.instance:CreateGUIWindow1("Layout", name)
    ui:SetArea(table.unpack(area))
    ui:SetTouchable(false)
    self.uiEffectContent:AddChildWindow(ui)
    ui:SetEffectName(name)
    uiEffects[name] = ui
    local effectTime = time or value.time
    ui:PlayEffect(effectTime or 10000000000)
    if effectTime and effectTime > 0 then
        uiEffectTimers[name] = World.Timer(effectTime, function()
            removeEffectView(name)
        end)
    end
end

function M:initGM()
    self.gmBtn = self:child("Main-GM")
    self.gmImg = self:child("Main-GMImg")
    local gmPosition = World.gameCfg.gmPosition or {}
    local x = gmPosition[1]
    local y = gmPosition[2]
    if x then
        self.gmBtn:SetXPosition(x)
    end
    if y then
        self.gmBtn:SetYPosition(y)
    end

    self:lightSubscribe("error!!!!! : win_main gmBtn event : EventWindowTouchDown", self.gmBtn, UIEvent.EventWindowTouchDown, function()
        self:onGMTouchDown()
    end)

    self:lightSubscribe("error!!!!! : win_main gmBtn event : EventWindowTouchMove", self.gmBtn, UIEvent.EventWindowTouchMove, function(window, dx, dy)
        self:onGMTouchMove(window, dx, dy)
    end)

    self:lightSubscribe("error!!!!! : win_main gmBtn event : EventWindowTouchMove", self.gmBtn, UIEvent.EventWindowTouchUp, function()
        self:onGMTouchUp()
    end)

    self:lightSubscribe("error!!!!! : win_main gmBtn event : EventWindowTouchMove", self.gmBtn, UIEvent.EventMotionRelease, function()
        self:onGMTouchUp()
    end)

    self:lightSubscribe("error!!!!! : win_main gmBtn event : EventWindowTouchMove", self.gmBtn, UIEvent.EventWindowDoubleClick, function()
        Lib.emitEvent(Event.EVENT_SHOW_GMBOARD)
    end)

    self.gmBtn:SetVisible(World.gameCfg.gm or false)
end

function M:initItemBar()
    self.itemBar = self:child("Main-ItemBarBg")
    if worldCfg.hideItemBar or isEditor then
        self.itemBar:SetVisible(false)
        return
    end
    self.itemBar:SetVisible(true)
    self.gridview = self:child("Main-VisibleBar-GridView")
    self:initItemBarItems()
    self:initItemBarCDMask()
    self:lightSubscribe("error!!!!! : win_main Main-ToggleInventoryButton event : EventWindowClick", self:child("Main-ToggleInventoryButton"), UIEvent.EventWindowClick, function()
        Lib.emitEvent(Event.EVENT_MAIN_ROLE, true)
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_PLAYER_ITEM_LOADED", Event.EVENT_PLAYER_ITEM_LOADED, function()
        self:updateBag()
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_PLAYER_ITEM_MODIFY", Event.EVENT_PLAYER_ITEM_MODIFY, function()
        self:updateBag()
    end)
end

function M:init()
    WinBase.init(self, "Main.json")
    self.itemCdMaskArr = {}
    self.uiEffectContent = self:child("Main-UIEffect")
    self.personal_shop = self:child("Main-Personal-Shop")
    if worldCfg.personalShop ~= nil then
       self.personal_shop:SetVisible(worldCfg.personalShop)
    end
    self.Main_niebie = self:child("Main-niebie")
    self.m_playSoundProgressBar = self:child("Main-Play-Sound-Slider")
    self.m_playSoundProgressBar:SetVisible(false)
    self.m_showProgressBar = self:child("Main-Sound-ProgressBar")
    self.m_showProgressBarText = self:child("Main-Sound-Countdown")
    self.m_playSoundTime = 0

    self.m_breakBlockProgress = self:child("Main-Break-Block-Progress-Nor")
    self.m_breakBlockTimer = nil

    self.m_mainGain = self:child("Main-Gain")
    self.gainTimer = nil
    self.delayGain = {}
    self:initGM()
    self:initItemBar()

    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_ADD_MAIN_GAIN", Event.EVENT_ADD_MAIN_GAIN, function(params)
        self:addGains(params.gains, params.offsetY)
    end)

    if worldCfg.showVars and #worldCfg.showVars > 0 then
        self.m_varsListView = self:child("Main-List")
        self:initVarsShow()
        Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_VARS_SYNC", Event.EVENT_VARS_SYNC,function(key, val)
            self:updateVarsShow(key, val)
        end)
    end

    checkUIEffectView(self)
    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_CHANGE_PERSONVIEW", Event.EVENT_CHANGE_PERSONVIEW, function()
        checkUIEffectView(self)
    end)
    
    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : PLAYE_UI_EFFECT", Event.PLAYE_UI_EFFECT, function(value, add, time)
        ui_effect(self, value, add, time)
    end)

    self:lightSubscribe("error!!!!! : win_main personal_shop event : EventButtonClick", self.personal_shop, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_OPEN_UPGRADE_SHOP, true)
    end)

    self:lightSubscribe("error!!!!! : win_main Main_niebie event : EventButtonClick", self.Main_niebie, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_OPEN_NEWBIE_FIRST, true)            
    end)

    local backBtn = self:child("Main-Back-Btn")
    if not isEditorEnvironment then
        backBtn:SetVisible(false)
    else
        self.personal_shop:SetVisible(false)
        backBtn:SetVisible(true)
        backBtn:SetEnabled(true)
        backBtn:SetNormalImage("set:mapEdit_back.json image:back")
        backBtn:SetPushedImage("set:mapEdit_back.json image:back")
        self:lightSubscribe("error!!!!! : win_main Main-Back-Btn event : EventButtonClick", backBtn, UIEvent.EventButtonClick, function()
            EditorModule:emitEvent("enterEditorMode")
        end)
    end

    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_SEND_ESPECIALLY_SHOP_UPDATE", Event.EVENT_SEND_ESPECIALLY_SHOP_UPDATE,function()
        self.personal_shop:SetVisible(worldCfg.personalShop == nil and true or worldCfg.personalShop)  
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_PLAY_SOUND_PROGRESSBAR", Event.EVENT_PLAY_SOUND_PROGRESSBAR, function(time)
        self:showPlaySoundProgressBar(time)
    end)

	Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_PLAYER_LOGIN", Event.EVENT_PLAYER_LOGIN, function(player)
        if worldCfg.needPlayerCheckin ~= false then
            self:playerCheckinMessage(Lang:toText({"system.message.player.enter.server", player.name}))
        end
	end)

	Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_PLAYER_LOGOUT", Event.EVENT_PLAYER_LOGOUT, function(player)
        if worldCfg.needPlayerCheckin ~= false then
            self:playerCheckinMessage(Lang:toText({"system.message.player.exit.server", player.name}))
        end
	end)

	Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_HAND_ITEM_CHANGE", Event.EVENT_HAND_ITEM_CHANGE, function(item)
		if World.cfg.hidehandItemName then
			return
		end
		if not item then
			self:child("Main-ShowHandItemName"):SetText("")
			return
		end
		local name
		if item:full_name() == "/block" then
			name = item:block_cfg().itemname
		else
			name = item:cfg().itemname
		end
		self:child("Main-ShowHandItemName"):SetText(Lang:toText(name or ""))
	end)

    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_SCENE_TOUCH_BEGIN", Event.EVENT_SCENE_TOUCH_BEGIN, function(x, y)
        self:breakBlockUIManage(true, x, y)
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_SCENE_TOUCH_MOVE", Event.EVENT_SCENE_TOUCH_MOVE, function(x, y)
        self:breakBlockUIManage(true, x, y)
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_SCENE_TOUCH_END", Event.EVENT_SCENE_TOUCH_END, function()
        self:breakBlockUIManage(false, 0, 0)
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_SCENE_TOUCH_CANCEL", Event.EVENT_SCENE_TOUCH_CANCEL, function()
        self:breakBlockUIManage(false, 0, 0)
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_BREAK_BLOCK_UI_MANAGE", Event.EVENT_BREAK_BLOCK_UI_MANAGE, function(state, progress)
        self:breakBlockProgress(state, progress)
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_GAME_PAUSE", Event.EVENT_GAME_PAUSE, function()
        Player.CurPlayer:stopGameBgm()
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_GAME_RESUME", Event.EVENT_GAME_RESUME, function()
        Player.CurPlayer:playGameBgm()
    end)

    self:lightSubscribe("error!!!!! : win_main Main_niebie event : EventButtonClick", self.Main_niebie, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_PLAYER_SHOWNOVICEGUIDE, guideFullName)
    end)

    if isEditorEnvironment then
        Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_PLAYER_SETNOVICEGUIDE", Event.EVENT_PLAYER_SETNOVICEGUIDE, function(fullName, image)
            guideFullName = fullName
            local guide = setting:fetch("explain", fullName or "") or {}
            self.Main_niebie:SetVisible(not worldCfg.hideNewbieGuide and guide and true or false)
            if image then
                self.Main_niebie:SetNormalImage(image)
                self.Main_niebie:SetPushedImage(image)
            end
        end)
    end
end

function M:enterEditorMode()
    Lib.emitEvent(Event.EVENT_STOP_DEAD_COUNTDOWN)
    Lib.emitEvent(Event.EVENT_CLOSE_ALL_WND)
    Lib.emitEvent(Event.EVENT_EDIT_MAP_MAKING)
    if self.deathEffectTimer then
        self.deathEffectTimer()
    end
    if self.deleteDeathEffect then
        self.deleteDeathEffect()
    end
    World.Timer(5, function()
            local gameRootPath = CGame.Instance():getGameRootDir()
            CGame.instance:restartGame(gameRootPath, World.GameName, 1, true)
            return false
    end)
end

function M:initItemBarItems()
    self.gridview:InitConfig(0, 0, MAX_COUNT)
    self.gridview:HasItemHidden(false)
    self.gridview:SetMoveAble(false)
    for slot = 1, MAX_COUNT do
        local cell = UIMgr:new_widget("cell")
        self:lightSubscribe("error!!!!! : win_main itemBarItem slot = "..slot.." event : EventWindowClick", cell, UIEvent.EventWindowClick, function()
            local item = cell:data("item")
            if item and item:cfg().fastUse then
                Skill.Cast("/useitem", {slot = item:slot(), tid = item:tid()})
            else
                Me:setHandItem(item)
                if self._select_cell then
                    self._select_cell:receiver():onClick(false)
                end
                self._select_cell = cell
                self._select_cell:receiver():onClick(true)
                Lib.emitEvent(Event.CHECK_SWAP, slot, cell)
            end
        end)
        cell:setEnableLongTouchRecursivly(true)
        self:lightSubscribe("error!!!!! : win_main itemBarItem slot = "..slot.." event : EventWindowLongTouchStart", cell, UIEvent.EventWindowLongTouchStart, function()
            cell:setData("abandonTimer",  World.Timer(World.cfg.abandonTouchTime or 8, function()
                local item = cell:data("item")
                local canAbandon = item and item:cfg().canAbandon
                if item and item:is_block() then
                    canAbandon = item:block_cfg().canAbandon
                end
                if canAbandon or World.cfg.allCanAbandon then
                    Me:sendPacket({pid = "AbandonItem", tid = item:tid(), slot = item:slot()})
                end
            end))
        end)
        self:lightSubscribe("error!!!!! : win_main itemBarItem slot = "..slot.." event : EventWindowLongTouchEnd", cell, UIEvent.EventWindowLongTouchEnd, function()
            local stopTimer = cell:data("abandonTimer")
            if stopTimer then
                stopTimer()
            end
        end)
        self.itemCdMaskArr[slot] = {cell = cell, lastCdEndTick = 0}
        self.gridview:AddItem(cell)
    end
end

local itemCDTimeMap = {}
local cellTimerTable = {}
local function delayUpdate(self)
    for key, value in pairs(cellTimerTable) do
        value.timer()
    end
    cellTimerTable = {}
    local now = World.Now()
    for _, cellInfo in pairs(self.itemCdMaskArr) do
        local cell = cellInfo.cell
        local item = cell:data("item")
        if item and not item:null() then
            local fullName = item:cfg().fullName
            local itemCd = itemCDTimeMap[fullName] or {}
            local endTick = itemCd.endTick
            if itemCd.startTick and endTick and endTick > now then
                local temp = cellTimerTable[fullName]
                if not temp then
                    temp = {cells = {}}
                    cellTimerTable[fullName] = temp
                end
                temp.cells[#temp.cells + 1] = cell
                temp.pack = {itemCd.startTick, now, endTick}
                goto continue
            end
        end
        cell:setMask(0)
        cell:setEnableLongTouchRecursivly(true) --�板�����僵涓��芥�′��挎��
        ::continue::
    end
    for key, value in pairs(cellTimerTable) do
        value.timer = UILib.updateMask(value.cells, table.unpack(value.pack))
    end
    self.delayTimer = nil
end

function M:initItemBarCDMask()
    Lib.lightSubscribeEvent("error!!!!! : win_main lib event : EVENT_UPDATE_ITEM_CD_MASK", Event.EVENT_UPDATE_ITEM_CD_MASK, function(value)
        if value then
            itemCDTimeMap = value
        end
        if self.delayTimer then
            return
        end
        self.delayTimer = World.Timer(5, delayUpdate, self)
    end)
end

function M:playerCheckinMessage(msg)
    if Blockman.instance.singleGame then
        return
    end
    Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, msg)
end

function M:onOpen()
    CGame.instance:onEditorDataReport("gametest_success", "")
end

function M:onClose()

end

function M:showPlaySoundProgressBar(time)
    if time <= 0 then
        self.m_playSoundProgressBar:SetVisible(false)
        return
    end
    self.m_playSoundProgressBar:SetVisible(true)
    self.m_playSoundTime = time
    local function tick()
        self.m_playSoundTime = self.m_playSoundTime - 1
        if self.m_playSoundTime <= 0 then
            self.m_playSoundProgressBar:SetVisible(false)
            return false
        end
        self.m_showProgressBarText:SetText(math.ceil(self.m_playSoundTime / 20))
        self.m_showProgressBar:SetProgress(self.m_playSoundTime / time)
        return true
    end
    World.Timer(1, tick)
end

function M:updateBag()
    if worldCfg.hideItemBar or isEditor then
        return
    end
    self:bagViewReset()
	local trayArray = Me:tray():query_trays(Define.TRAY_TYPE.HAND_BAG)

	local idx = 0
    for _, element in pairs(trayArray) do
        local tid, tray = element.tid, element.tray
		local items = tray:query_items()
		for slot, item in pairs(items) do
			self:bagViewUpdateItem(item, slot - 1)
			idx = idx + 1
			if idx >= MAX_COUNT then
				break
			end
		end
	end
    if self._select_cell then
        Me:setHandItem(self._select_cell:data("item"))
    end
end

function M:bagViewReset()
    for i = 0, self.gridview:GetItemCount() - 1 do
        local cell = self.gridview:GetItem(i)
        if cell then
            cell:setData("item")
            cell:invoke("RESET")
        end
    end
    Lib.emitEvent(Event.EVENT_UPDATE_ITEM_CD_MASK)
end

function M:bagViewUpdateItem(item, idx)
    local cell = self.gridview:GetItem(idx)
    cell:setData("item", item)
    cell:invoke("ITEM_SLOTER", item)
    cell:invoke("SET_BG", item)
    cell:SetName("item:"..item:full_name())
    Lib.emitEvent(Event.EVENT_UPDATE_ITEM_CD_MASK)
end

function M:initVarsShow()
    self:child("Main-ListBg"):SetVisible(true)
    self:child("Main-ListBg"):SetHeight({0, 30 * #worldCfg.showVars + 5})
    for i = 1, #worldCfg.showVars do
        local temp = worldCfg.showVars[i]
        local text = UIMgr:new_widget("text", 50, 30, Lang:toText(temp.disc), temp.value or 0) --todo width height
        self.m_varsListView:AddItem1(text, 0, i - 1)
        key2index[temp.key] = i - 1
    end
end

function M:updateVarsShow(key, val)
    local index = key2index[key]
    if index and self.m_varsListView:getContainerWindow() then
        local text = self.m_varsListView:getContainerWindow():GetChildByIndex(index)
        text:invoke("SETTEXT", val)
    end
end

function M:onGMTouchDown()
    self.xPosition = self.gmBtn:GetXPosition()
    self.yPosition = self.gmBtn:GetYPosition()
    self.gmImg:SetXPosition(self.xPosition)
    self.gmImg:SetYPosition(self.yPosition)
    self.gmBtn:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
end

function M:onGMTouchMove(window, dx, dy)
    self.gmImg:SetXPosition({0, dx - 25})
    self.gmImg:SetYPosition({0, dy - 25})
end

function M:onGMTouchUp()
    self.xPosition = self.gmImg:GetXPosition()
    self.yPosition = self.gmImg:GetYPosition()
    self.gmBtn:SetArea(self.xPosition, self.yPosition, {0, 50}, {0, 50})
    self.gmImg:SetArea({0, 0}, {0, 0}, {0, 50}, {0, 50})
end

function M:dropItem(item)
	local packet = {
		pid = "DropInventoryItem",
		tid = item and (not item:null()) and item:tid(),
		slot = item and (not item:null()) and item:slot()
	}
	Me:sendPacket(packet)
end

function M:breakBlockUIManage(isShow, x, y)
    if worldCfg.disableBreakBlockProgress then
        return
    end
    if self.m_breakBlockProgress then
        self.m_breakBlockProgress:SetVisible(isShow)
        self.m_breakBlockProgress:SetArea({ 0, x - 90 }, { 0, y - 90 }, { 0, 180 }, { 0, 180 })
    end
end

function M:breakBlockProgress(state, progress)
    if worldCfg.disableBreakBlockProgress then
        return
    end
    self.m_breakBlockProgress:SetVisible(state)
    local progress_ui = self.m_breakBlockProgress:GetChildByIndex(0)
    progress_ui:SetArea({ 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 })
    if self.m_breakBlockTimer then
        self.m_breakBlockTimer()
    end
    if not state then
        return
    end
    local _progress = 0
    progress_ui:SetArea({ 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 })

    self.m_breakBlockTimer = World.Timer(1, function ()
        _progress = math.min(_progress + 1, progress)
        if _progress == progress then
            self.m_breakBlockProgress:SetVisible(false)
            progress_ui:SetArea({ 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 })
            self.m_breakBlockTimer = nil
            return false
        end

        progress_ui:SetArea({ 0, 0 }, { 0, 0 }, { _progress / progress, 0 }, { _progress / progress, 0 })
        return true
    end)
end

function M:addGains(gains, offsetY)
    for _, gain in ipairs(gains) do
        self:addGain(gain.type, gain.fullName, gain.count, offsetY)
    end
end

function M:addGain(type, fullName, count, offsetY)
    local icon = ResLoader:getIcon(type, fullName)
    local gain = GUIWindowManager.instance:CreateWindowFromTemplate("gain_item", "GainItem.json")
    gain:GetChildByIndex(0):SetImage(icon)
    gain:GetChildByIndex(1):SetText("X" .. Lib.switchNum(count))
    self.m_mainGain:SetArea({ 0, 0 }, { 0, offsetY and -offsetY or 0 }, { 0, 70 }, { 0, 35})
    table.insert(self.delayGain, gain)
    local function startGain()
        local g = self.delayGain[1]
        if not g and self.gainTimer then
            self.gainTimer()
            self.gainTimer = nil
            return false
        end
        self.m_mainGain:AddChildWindow(g)
        UILib.uiTween(g, {
            Y = {0,-80},
            Alpha = 0
        }, 30, function()
            self:subGain(g)
        end)
        table.remove(self.delayGain, 1)
        return true
    end
    if not self.gainTimer then
        startGain()
        self.gainTimer = World.Timer(5, startGain)
    end
end

function M:subGain(gain)
    self.m_mainGain:RemoveChildWindow1(gain)
    if #self.delayGain == 0 and self.gainTimer then
        self.gainTimer()
        self.gainTimer = nil
    end
end

function M:onReload()
	self:updateBag()
end

function M:showGM(show)
    self:child("Main-GM"):SetVisible(show)
end

return M

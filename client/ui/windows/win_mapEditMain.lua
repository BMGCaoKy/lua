local setting = require "common.setting"
local data_state = require "editor.dataState"

local GUI_WIDTH_SIZE = 0.075
local GUI_HEIGHT_SIZE = 0.502777

local stopTimer = nil

function M:init()
	WinBase.init(self, "main_edit.json")
	
	self._wnd_poleBg = self:child("Main-PoleControl-bg")
	self._wnd_poleCenter = self:child("Main-PoleControl-Center")
	self._wnd_poleMove = self:child("Main-PoleControl-Move")
	self.m_breakBlockProgress = self:child("Main-Main-Break-Block-Progress-Nor")
	self:initSetting()

    self:subscribe(self:child("MainControl-forward"), UIEvent.EventWindowTouchDown, function()
        Blockman.instance:setKeyPressing("key.forward", true)
    end)

    self:subscribe(self:child("MainControl-forward"), UIEvent.EventMotionRelease, function()
        Blockman.instance:setKeyPressing("key.forward", false)
    end)

    self:subscribe(self:child("MainControl-forward"), UIEvent.EventWindowTouchUp, function()
        Blockman.instance:setKeyPressing("key.forward", false)
    end)

    self:subscribe(self:child("MainControl-back"), UIEvent.EventWindowTouchDown, function()
        Blockman.instance:setKeyPressing("key.back", true)
    end)

    self:subscribe(self:child("MainControl-back"), UIEvent.EventMotionRelease, function()
        Blockman.instance:setKeyPressing("key.back", false)
    end)

    self:subscribe(self:child("MainControl-back"), UIEvent.EventWindowTouchUp, function()
        Blockman.instance:setKeyPressing("key.back", false)
    end)

    self:subscribe(self:child("MainControl-left"), UIEvent.EventWindowTouchDown, function()
        Blockman.instance:setKeyPressing("key.left", true)
    end)

    self:subscribe(self:child("MainControl-left"), UIEvent.EventMotionRelease, function()
        Blockman.instance:setKeyPressing("key.left", false)
    end)

    self:subscribe(self:child("MainControl-left"), UIEvent.EventWindowTouchUp, function()
        Blockman.instance:setKeyPressing("key.left", false)
    end)

    self:subscribe(self:child("MainControl-right"), UIEvent.EventWindowTouchDown, function()
        Blockman.instance:setKeyPressing("key.right", true)
    end)

    self:subscribe(self:child("MainControl-right"), UIEvent.EventMotionRelease, function()
        Blockman.instance:setKeyPressing("key.right", false)
    end)

    self:subscribe(self:child("MainControl-right"), UIEvent.EventWindowTouchUp, function()
        Blockman.instance:setKeyPressing("key.right", false)
    end)

    self.riseBtn = self:child("Main-EditPlayerControl-Fly-Rise")
    self.descendBtn = self:child("Main-EditPlayerControl-Fly-Descend")
    self:child("Main-EditPlayerControl-Fly"):setBelongWhitelist(true)
    self:child("Main-Jump"):setBelongWhitelist(true)

    local function onPressKeyRise()
        self.riseBtn:SetImage("set:map_edit_main.json image:icon_up_act")
		Blockman.instance:setKeyPressing("key.rise", true)
	end
    local function onReleaseKeyRise()
        self.riseBtn:SetImage("set:map_edit_main.json image:icon_up_nor")
		Blockman.instance:setKeyPressing("key.rise", false)
	end
    local function onPressKeyDescend()
        self.descendBtn:SetImage("set:map_edit_main.json image:icon_down_act")
		Blockman.instance:setKeyPressing("key.descend", true)
	end
    local function onReleaseKeyDescend()
        self.descendBtn:SetImage("set:map_edit_main.json image:icon_down_nor")
		Blockman.instance:setKeyPressing("key.descend", false)
    end
    
    self:subscribe(self.riseBtn, UIEvent.EventWindowTouchDown, onPressKeyRise)
    self:subscribe(self.riseBtn, UIEvent.EventMotionRelease, onReleaseKeyRise)
    self:subscribe(self.riseBtn, UIEvent.EventWindowTouchUp, onReleaseKeyRise)
    self:subscribe(self.descendBtn, UIEvent.EventWindowTouchDown, onPressKeyDescend)
    self:subscribe(self.descendBtn, UIEvent.EventMotionRelease, onReleaseKeyDescend)
    self:subscribe(self.descendBtn, UIEvent.EventWindowTouchUp, onReleaseKeyDescend)

    Lib.subscribeEvent(Event.EVENT_UPDATE_JUMP_PROGRESS, function(tb)
        EditorModule:getMoveControl():jump()
    end)

    self:subscribe(self:child("Main-Jump"), UIEvent.EventWindowTouchDown, function()
        self:child("Main-Jump"):SetImage("set:map_edit_main.json image:icon_jump_act")
        Blockman.instance:setKeyPressing("key.jump", true)
        EditorModule:getMoveControl():jump()
    end)

    self:subscribe(self:child("Main-Jump"), UIEvent.EventMotionRelease, function()
        self:child("Main-Jump"):SetImage("set:map_edit_main.json image:icon_jump_nor")
        Blockman.instance:setKeyPressing("key.jump", false)
    end)

    self:subscribe(self:child("Main-Jump"), UIEvent.EventWindowTouchUp, function()
        self:child("Main-Jump"):SetImage("set:map_edit_main.json image:icon_jump_nor")
        Blockman.instance:setKeyPressing("key.jump", false)
    end)

    self:subscribe(self:child("Main-PoleControl-Move"), UIEvent.EventWindowTouchDown, function()
        self:onPoleTouchDown()
    end)

    self:subscribe(self:child("Main-PoleControl-Move"), UIEvent.EventWindowTouchMove, function(window, dx, dy)
        self:onPoleTouchMove(window, dx, dy)
    end)

    self:subscribe(self:child("Main-PoleControl-Move"), UIEvent.EventWindowTouchUp, function()
        self:onPoleTouchUp()
    end)

    self:subscribe(self:child("Main-PoleControl-Move"), UIEvent.EventMotionRelease, function()
        self:onPoleTouchUp()
    end)
    self.guideWnd = self:child("Main-Course")
    self:subscribe(self.guideWnd, UIEvent.EventWindowTouchUp, function()
        local guideWndName = self.guideWnd:GetName()
        if guideWndName == "TempCourse" then
            Lib.emitEvent(Event.EVENT_GUIDE_PLACE_ENTITY, {x = 49, y = 3, z = 51})
        elseif guideWndName == "TempMainCourse" then
            Lib.emitEvent(Event.EVENT_GUIDE_PLACE_ENTITY, {x = 50, y = 3, z = 45})
        elseif guideWndName == "TempMainMonster" then
            Lib.emitEvent(Event.EVENT_GUIDE_PLACE_ENTITY, nil, true)
        end
    end)

	Lib.subscribeEvent(Event.EVENT_SET_GUI_SIZE, function()
		self:updateGuiSize()
    end)

	Lib.subscribeEvent(Event.EVENT_SWITCH_MOVE_CONTROL, function(usePole)
        if usePole > 0 then
            CGame.instance:onEditorDataReport("click_setting_disc_operation", "")
        else
            CGame.instance:onEditorDataReport("click_setting_arrow_key_operation", "")
        end
        
		self:switchMoveControl(usePole)
    end)

	Lib.subscribeEvent(Event.EVENT_PACK_SWAP_ITEM, function(swapItem)
		self.packSelectItem = swapItem
	end)

	Lib.subscribeEvent(Event.EVENT_PACK_CLOSE_PACK, function(cell)
		self.packSelectItem = nil
	end)

    Lib.subscribeEvent(Event.EVENT_CHANGE_MAIN_UI_STATE, function(cfg)
        if cfg.isFly ~= nil then
            self:child("Main-EditPlayerControl-Fly"):SetVisible(cfg.isFly)
            self:child("Main-Jump-Controls"):SetVisible(not cfg.isFly)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_OPEN_INVENTORY, function(flag)
        Lib.emitEvent(Event.EVENT_EDIT_OPEN_SHORTCUT, flag)
    end)

    Lib.subscribeEvent(Event.EVENT_EDIT_INFORM_MAIN_WND, function(msg, offsetY)
		self:showItemInfoTip(msg, offsetY)
	end) 

	Lib.subscribeEvent(Event.EVENT_SCENE_TOUCH_BEGIN, function(x, y)
        self:breakBlockUIManage(true, x, y)
    end)

    Lib.subscribeEvent(Event.EVENT_SCENE_TOUCH_MOVE, function(x, y)
        self:breakBlockUIManage(true, x, y)
    end)

    Lib.subscribeEvent(Event.EVENT_SCENE_TOUCH_END, function()
        self:breakBlockUIManage(false, 0, 0)
    end)

    Lib.subscribeEvent(Event.EVENT_SCENE_TOUCH_CANCEL, function()
        self:breakBlockUIManage(false, 0, 0)
    end)

	Lib.subscribeEvent(Event.EVENT_BREAK_BLOCK_UI_MANAGE, function(state, progress)
        self:breakBlockProgress(state, progress)
    end)

    Lib.subscribeEvent(Event.EVENT_NOVICE_GUIDE, function(indexType, isFinish)
        if indexType == 3 and self:child("Main-Course") then
            self:child("Main-Course"):SetName("TempCourse")
        elseif indexType == 6 and self:child("TempCourse") then
            self:child("TempCourse"):SetArea({0.55, 0}, {0.498611, 0}, {0.101562, 0}, {0.180556, 0})
            self:child("TempCourse"):SetName("TempMainCourse")
        elseif indexType == 8 and self:child("TempMainCourse") then
            self:child("TempMainCourse"):SetName("TempMainMonster")
            self:child("Main-Switch-Pack"):SetYPosition({0 , 588})
        elseif indexType == 9 then
            self:child("Main-Switch-Pack"):SetYPosition({0 , 550})
        end
    end)

end

function M:breakBlockUIManage(isShow, x, y)
    if self.m_breakBlockProgress then
        self.m_breakBlockProgress:SetVisible(isShow)
        self.m_breakBlockProgress:SetArea({ 0, x - 90 }, { 0, y - 90 }, { 0, 180 }, { 0, 180 })
    end
end

function M:breakBlockProgress(state, progress)
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
            return false
        end

        progress_ui:SetArea({ 0, 0 }, { 0, 0 }, { _progress / progress, 0 }, { _progress / progress, 0 })
        return true
    end)
end

function M:showItemInfoTip(str, offsetY)
	local tipInfo = self:child("Main-Switch-Pack")
	if str == "" then
		tipInfo:SetVisible(false)
		return
    end
    tipInfo:SetYPosition({0, 588 - offsetY})
	tipInfo:SetVisible(true)
	local width = tipInfo:GetFont():GetTextExtent(str,1.0) + 50
	tipInfo:SetWidth({0 , width })
	self:child("Main-Switch-Pack"):SetText(str)
	if stopTimer then
		stopTimer()
	end
	self:closeSwitchPack()
end

function M:closeSwitchPack()
    local a = 0
    local function tick()
        a = a + 1
        if a >= 2 then
            self:child("Main-Switch-Pack"):SetVisible(false)
            return false
        else
            return true
        end
    end
    stopTimer = World.Timer(20, tick)
end

function M:initSetting()
	self:updateGuiSize()

	self:switchMoveControl(Blockman.instance.gameSettings.usePole)

	self.originPolePosX = self._wnd_poleCenter:GetXPosition()
	self.originPolePosY = self._wnd_poleCenter:GetYPosition()
	local rect = self._wnd_poleCenter:GetUnclippedOuterRect()
	self.originPoleAbsPosX = rect[1] + self._wnd_poleCenter:GetPixelSize().x / 2
	self.originPoleAbsPosY = rect[2] + self._wnd_poleCenter:GetPixelSize().y / 2
	self._wnd_poleBg:SetAlpha(0.75)

end

function M:updateGuiSize()
    local mainControl = self:child("Main-Control")
	local poleControl = self:child("Main-PoleControl")
	local width = Blockman.instance.gameSettings:getMainGuiWidth()
	local height = Blockman.instance.gameSettings:getMainGuiHeight()
    mainControl:setBelongWhitelist(true)
    poleControl:setBelongWhitelist(true)
	local size = Blockman.instance.gameSettings.playerActivityGuiSize
	local mainJumpControl = self:child("Main-Jump")
	mainJumpControl:SetWidth({size, 0})
	mainJumpControl:SetHeight({size, 0})
end

function M:switchMoveControl(isDefault)
	self:child("Main-PoleControl"):SetVisible(isDefault > 0)
	self:child("Main-Control"):SetVisible(not(isDefault > 0))
end

function M:onPoleTouchDown()
	self._wnd_poleMove:SetArea({0, -50}, {-1.25, 70}, {2, 0}, {2.25, 0})
	self._wnd_poleBg:SetAlpha(0.5)
end

function M:onPoleTouchMove(window, dx, dy)
	local fMaxDis = 95.0
	local offX = dx - self.originPoleAbsPosX
	local offY = dy - self.originPoleAbsPosY
	local disSqr = offX * offX + offY * offY
	if disSqr > fMaxDis * fMaxDis then
		local rate = math.sqrt(fMaxDis * fMaxDis / disSqr)
		offX = offX * rate
		offY = offY * rate
		disSqr = fMaxDis * fMaxDis
	end
	self._wnd_poleCenter:SetXPosition({0, (self.originPolePosX[2] + offX)})
	self._wnd_poleCenter:SetYPosition({0, (self.originPolePosY[2] + offY)})
	local poleForward = -offY / math.sqrt(disSqr)
	local poleStrafe = -offX / math.sqrt(disSqr)
	Blockman.instance.gameSettings.poleForward = poleForward
	Blockman.instance.gameSettings.poleStrafe = poleStrafe
end

function M:onPoleTouchUp()
	self._wnd_poleMove:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
	self._wnd_poleCenter:SetXPosition(self.originPolePosX)
	self._wnd_poleCenter:SetYPosition(self.originPolePosY)
	self._wnd_poleBg:SetAlpha(0.75)
	Blockman.instance.gameSettings.poleForward = 0
	Blockman.instance.gameSettings.poleStrafe = 0
end

function M:onClose()
    Lib.emitEvent(Event.EVENT_EDIT_OPEN_SHORTCUT, false)
end

function M:onOpen()
	Lib.emitEvent(Event.EVENT_EDIT_OPEN_SHORTCUT, true)
end

function M:onReload()
end

return M

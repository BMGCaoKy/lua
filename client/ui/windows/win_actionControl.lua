
local v_alignment = {LEFT = 0, CENTER = 1, RIGHT = 2, TOP = 0, CENTER = 1, BOTTOM = 2}
local H_alignment = {LEFT = 0, CENTER = 1, RIGHT = 2, TOP = 0, CENTER = 1, BOTTOM = 2}
local worldCfg = World.cfg
local screenToWindowX = CoordConverter.screenToWindowX1
local screenToWindowY = CoordConverter.screenToWindowY1
local dragAreaSize = worldCfg.dragAreaSize or 240
local dragAreaStartPoint = worldCfg.dragAreaStartPoint or {40,-70}
local dragAreaOffset = worldCfg.dragAreaOffset or 0
local dragAreaRadius = dragAreaSize / 2
local ti = TouchManager:Instance()

local friendFollowShield = {
    ---好友跟随模式下应该屏蔽的UI
    ["Main-Jump-Controls"] = true,
    ["Main-Jump"] = true,
    ["Main-Sneak"] = true,
    ["Main-MoveState"] = true,
    ["Main-MoveState-Sneak"] = true,
    ["Main-MoveState-Run"] = true
}

local misc = require "misc"
local now_nanoseconds = misc.now_nanoseconds
local function getTime()
    return now_nanoseconds() / 1000000
end

local function check2SetVisible(self, widget, visible)
    if not widget then
        return
    end
    local isWatcher = next(Me) and Me:isWatch()
    widget = type(widget) == "string" and widget or widget:GetName()
    visible = ((visible and isWatcher) and {not friendFollowShield[widget]} or {visible})[1]
    self:child(widget):SetVisible(visible)
end

local function initFlyBtn(self)
    local cfg = World.cfg.flyBtnSetting or {}
    local area = cfg.area
    local hideJumpWhenFly = cfg.hideJumpWhenFly
    local norUpIcon = cfg.norUpIcon or "set:fly.json image:fly_up_normal.png"
    local pushUpIcon = cfg.pushUpIcon or "set:fly.json image:fly_up_push.png"
    local norDownIcon = cfg.norDownIcon or "set:fly.json image:fly_down_normal.png"
    local pushDownIcon = cfg.pushDownIcon or "set:fly.json image:fly_down_push.png"

    local contentArea = cfg.area or {{0, -20}, {0, -60}, {0, 192}, {0, 210}}
    local x, y, w, h = table.unpack(contentArea)
    local content = GUIWindowManager.instance:CreateGUIWindow1("Layout", "Main-FlyContent")
    content:SetArea(table.unpack(contentArea))
    content:SetHorizontalAlignment(cfg.hAlign or 2)
    content:SetVerticalAlignment(cfg.vAlign or 2)
    self._root:AddChildWindow(content)
    check2SetVisible(self, content, false)
    local up = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "up")
    up:SetImage(norUpIcon)
    up:SetArea(table.unpack(cfg.upArea or {{0, 0}, {0, 0}, {1, 0}, {0, h[2] * 0.5}}))
    up:SetVerticalAlignment(0)
    content:AddChildWindow(up)
    local down = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "down")
    down:SetImage(norDownIcon)
    down:SetArea(table.unpack(cfg.downArea or {{0, 0}, {0, 0}, {1, 0}, {0, h[2] * 0.5}}))
    down:SetVerticalAlignment(2)
    content:AddChildWindow(down)

    local control = Blockman.Instance():control()
    local function flyBegin(wnd, dx, dy)
        local posY = screenToWindowY(wnd, dy)
        local height = wnd:GetPixelSize().y
        local flyUp = posY <= height * 0.5
        up:SetImage(flyUp and pushUpIcon or norUpIcon)
        down:SetImage(flyUp and norDownIcon or pushDownIcon)
        control:setVerticalSpeed(flyUp and 1 or -1)
    end
    local function flyEnd()
        up:SetImage(norUpIcon)
        down:SetImage(norDownIcon)
        control:setVerticalSpeed(0)
    end

    content:lightSubscribe("error!!!!! : win_actionControl fly content event : EventWindowTouchDown", UIEvent.EventWindowTouchDown, function(wnd, dx, dy)
        flyBegin(wnd, dx, dy)
    end)
    content:lightSubscribe("error!!!!! : win_actionControl fly content event : EventWindowTouchMove", UIEvent.EventWindowTouchMove, function(wnd, dx, dy)
        flyBegin(wnd, dx, dy)
    end)
    content:lightSubscribe("error!!!!! : win_actionControl fly content event : EventWindowTouchUp", UIEvent.EventWindowTouchUp, function()
        flyEnd()
    end)
    content:lightSubscribe("error!!!!! : win_actionControl fly content event : EventMotionRelease", UIEvent.EventMotionRelease, function()
        flyEnd()
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_actionControl lib event : EVENT_UPDATE_FLY_STATE", Event.EVENT_UPDATE_FLY_STATE, function(state)
        check2SetVisible(self, content, state)
        flyEnd()
        if cfg.hideJumpWhenFly then
            check2SetVisible(self, "Main-Jump", not state)
        end
    end)
end

function M:initDragControl()
    if PlatformUtil.isPlatformWindows() or (not worldCfg.isDragControl) then
        return
    end
    self.dragControlMove = self:child("Main-DragControl-Move")
    self.dragControl = self:child("Main-DragControl")
    self.dragControl:SetArea({0, dragAreaStartPoint[1]}, {0, dragAreaStartPoint[2]}, {0, dragAreaSize}, {0, dragAreaSize})

    self.dragPointContent = self:child("Main-DragControl-PointContent")
    if dragAreaOffset >0 then
        self.dragControlMove:SetHorizontalAlignment(1)
        self.dragControlMove:SetVerticalAlignment(1)
        self.dragPointContent:SetHorizontalAlignment(1)
        self.dragPointContent:SetVerticalAlignment(1)
        self.dragControlMove:SetArea({0, 0}, {0, 0}, {1+dragAreaOffset, 0}, {1+dragAreaOffset, 0})
        self.dragPointContent:SetArea({0, 0}, {0, 0}, {1+dragAreaOffset, 0}, {1+dragAreaOffset, 0})
    end
    self.dragPoints = {}
    self.dragControl:SetImage(worldCfg.dragNormalImage or "")

    local size = {13, 16, 19, 21, 61}
    for i = 1, 5 do
        local radius = size[i]
        local point = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "DragControl-Point" .. i)
        point:SetArea({0, 0}, {0, 0}, {0, radius}, {0, radius})
        point:SetTouchable(false)
        point:SetImage("set:endless_main.json image:control_" .. i .. ".png")
        self.dragPointContent:AddChildWindow(point)
        table.insert(self.dragPoints, point)
    end

    self:lightSubscribe("error!!!!! : win_actionControl dragControlMove event : EventWindowTouchDown", self.dragControlMove, UIEvent.EventWindowTouchDown, function(window, dx, dy)
        self:onDragTouchDown(window, dx, dy)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl dragControlMove event : EventWindowTouchMove", self.dragControlMove, UIEvent.EventWindowTouchMove, function(window, dx, dy)
        self:onDragTouchMove(window, dx, dy)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl dragControlMove event : EventWindowTouchUp", self.dragControlMove, UIEvent.EventWindowTouchUp, function()
        self:onDragTouchUp()
    end)

    self:lightSubscribe("error!!!!! : win_actionControl dragControlMove event : EventMotionRelease", self.dragControlMove, UIEvent.EventMotionRelease, function()
        self:onDragTouchUp()
    end)
end

function M:initStateControlConpoment()
    self:lightSubscribe("error!!!!! : win_actionControl Main-Sneak event : EventWindowDoubleClick", self:child("Main-Sneak"), UIEvent.EventWindowDoubleClick, function()
		local sneakPressed = Blockman.instance:isKeyPressing("key.sneak")
		Blockman.instance:setKeyPressing("key.sneak", not sneakPressed)
        check2SetVisible(self, "Main-MoveState-Sneak", not sneakPressed)
        check2SetVisible(self, "Main-MoveState-Run", sneakPressed)
		if sneakPressed then
			self:child("Main-Sneak"):SetAlpha(0.9)
		else
			self:child("Main-Sneak"):SetAlpha(0.6)
		end
    end)

    self:lightSubscribe("error!!!!! : win_actionControl MainControl-sneak event : EventWindowDoubleClick", self:child("MainControl-sneak"), UIEvent.EventWindowDoubleClick, function()
        local sneakPressed = Blockman.instance:isKeyPressing("key.sneak")
		Blockman.instance:setKeyPressing("key.sneak", not sneakPressed)
        check2SetVisible(self, "Main-MoveState-Sneak", not sneakPressed)
        check2SetVisible(self, "Main-MoveState-Run", sneakPressed)
		if sneakPressed then
			self:child("MainControl-sneak"):SetAlpha(0.9)
		else
			self:child("MainControl-sneak"):SetAlpha(0.6)
		end
    end)

    self:lightSubscribe("error!!!!! : win_actionControl Main-MoveState-Sneak event : EventWindowClick", self:child("Main-MoveState-Sneak"), UIEvent.EventWindowClick, function()
        Blockman.instance:setKeyPressing("key.sneak", false)
        check2SetVisible(self, "Main-MoveState-Sneak", false)
        check2SetVisible(self, "Main-MoveState-Run", true)
		self:child("MainControl-sneak"):SetAlpha(0.9)
		self:child("Main-Sneak"):SetAlpha(0.9)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl Main-MoveState-Run event : EventWindowClick", self:child("Main-MoveState-Run"), UIEvent.EventWindowClick, function()
        Blockman.instance:setKeyPressing("key.sneak", true)
        check2SetVisible(self, "Main-MoveState-Sneak", true)
        check2SetVisible(self, "Main-MoveState-Run", false)
		self:child("MainControl-sneak"):SetAlpha(0.6)
		self:child("Main-Sneak"):SetAlpha(0.6)
    end)

    local skillJack = worldCfg.skillJack
    if not skillJack then
        return
    end
    if skillJack.AJackArea then
        self:child("Main-Jump-Controls"):SetArea(table.unpack(skillJack.AJackArea))
    end
    if skillJack.AJackIcon then
        check2SetVisible(self, "Main-Jump-Controls", true)
        self:child("Main-Jump-Controls"):SetImage(skillJack.AJackIcon)
        self.mainJump:SetImage("")
        self.mainJump:SetImage("")
    end
    if skillJack.hideAJack then
        check2SetVisible(self, "Main-Jump-Controls", false)
    end
    if skillJack.BJackArea then
        self:child("Main-MoveState"):SetArea(table.unpack(skillJack.BJackArea))
    end
    if skillJack.BJackIcon then
        check2SetVisible(self, "Main-MoveState", true)
        self:child("Main-MoveState"):SetImage(skillJack.BJackIcon)
        self:child("Main-MoveState-Sneak"):SetImage("")
        self:child("Main-MoveState-Run"):SetImage("")
    end
    if skillJack.hideBJack then
        check2SetVisible(self, "Main-MoveState", false)
    end
end

function M:initJumpProgress()
    if not worldCfg.jumpProgressIcon then
        return 
    end
    local mainJumpControls = self:child("Main-Jump-Controls")
    local progress = worldCfg.jumpProgressIconIncrementSize or 10
    local area = {{0, mainJumpControls:GetXPosition()[2] + progress/2}, {0, mainJumpControls:GetYPosition()[2] + progress/2}, 
        {0, mainJumpControls:GetPixelSize().x + progress}, {0, mainJumpControls:GetPixelSize().y + progress}}
    local image = self:fetchImageCell("jumpProgressIcon",area,self.mainJump:GetLevel() + 1,worldCfg.jumpProgressIcon,false,false,false,"jumpProgressIcon")
    self._root:AddChildWindow(image)
    self.jumpProgressIcon = image

    local jumpTimer = "jumpTimer"
    Lib.lightSubscribeEvent("error!!!!! : win_actionControl lib event : EVENT_UPDATE_JUMP_PROGRESS", Event.EVENT_UPDATE_JUMP_PROGRESS, function(tb)
        local jumpProgressIcon = self.jumpProgressIcon
        if not jumpProgressIcon then
            return
        end
        self.maskTimer = self.maskTimer or {}
        local progressTimer = self.maskTimer[jumpTimer]
        if tb.jumpStop then
            if progressTimer then
                progressTimer()
                self.maskTimer[jumpTimer] = nil
            end
            check2SetVisible(self, jumpProgressIcon, false)
        elseif tb.jumpStart and not progressTimer then
            check2SetVisible(self, jumpProgressIcon, true)
            if tb.jumpBeginTime < tb.jumpEndTime then
                self:updateMask(tb.jumpBeginTime, tb.jumpEndTime, jumpProgressIcon, jumpTimer)
            end
		end
    end)
end

function M:initMoveControl()
    if worldCfg.isDragControl then
        return
    end
    local MainControl_forward= self:child("MainControl-forward")
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_forward event : EventWindowTouchDown", MainControl_forward, UIEvent.EventWindowTouchDown, function()
        Blockman.instance:setKeyPressing("key.forward", true)
		self:showMainControlTopLeftRight(true)
    end)
	
	local MainControl_forward= self:child("MainControl-forward")
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_forward event : EventWindowTouchMove", MainControl_forward, UIEvent.EventWindowTouchMove, function()
        Blockman.instance:setKeyPressing("key.forward", true)
		self:showMainControlTopLeftRight(true)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl MainControl_forward event : EventMotionRelease", MainControl_forward, UIEvent.EventMotionRelease, function()
        Blockman.instance:setKeyPressing("key.forward", false)
		self:checkHideMainControlTopLeftRight()
    end)

    self:lightSubscribe("error!!!!! : win_actionControl MainControl_forward event : EventWindowTouchUp", MainControl_forward, UIEvent.EventWindowTouchUp, function()
        Blockman.instance:setKeyPressing("key.forward", false)
		self:checkHideMainControlTopLeftRight()
    end)

    local MainControl_back= self:child("MainControl-back")
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_back event : EventWindowTouchDown", MainControl_back, UIEvent.EventWindowTouchDown, function()
        Blockman.instance:setKeyPressing("key.back", true)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl MainControl_back event : EventMotionRelease", MainControl_back, UIEvent.EventMotionRelease, function()
        Blockman.instance:setKeyPressing("key.back", false)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl MainControl_back event : EventWindowTouchUp", MainControl_back, UIEvent.EventWindowTouchUp, function()
        Blockman.instance:setKeyPressing("key.back", false)
    end)

    local MainControl_left= self:child("MainControl-left")
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_left event : EventWindowTouchDown", MainControl_left, UIEvent.EventWindowTouchDown, function()
        Blockman.instance:setKeyPressing("key.left", true)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl MainControl_left event : EventMotionRelease", MainControl_left, UIEvent.EventMotionRelease, function()
        Blockman.instance:setKeyPressing("key.left", false)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl MainControl_left event : EventWindowTouchUp", MainControl_left, UIEvent.EventWindowTouchUp, function()
        Blockman.instance:setKeyPressing("key.left", false)
    end)

    local MainControl_right= self:child("MainControl-right")
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_right event : EventWindowTouchDown", MainControl_right, UIEvent.EventWindowTouchDown, function()
        Blockman.instance:setKeyPressing("key.right", true)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl MainControl_right event : EventMotionRelease", MainControl_right, UIEvent.EventMotionRelease, function()
        Blockman.instance:setKeyPressing("key.right", false)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl MainControl_right event : EventWindowTouchUp", MainControl_right, UIEvent.EventWindowTouchUp, function()
        Blockman.instance:setKeyPressing("key.right", false)
    end)

    local MainControl_jump= self:child("MainControl-jump")
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_jump event : EventWindowTouchDown", MainControl_jump, UIEvent.EventWindowTouchDown, function()
        Blockman.instance:setKeyPressing("key.jump", true)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl MainControl_jump event : EventMotionRelease", MainControl_jump, UIEvent.EventMotionRelease, function()
        Blockman.instance:setKeyPressing("key.jump", false)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl MainControl_jump event : EventWindowTouchUp", MainControl_jump, UIEvent.EventWindowTouchUp, function()
        Blockman.instance:setKeyPressing("key.jump", false)
    end)

	local function onPressKeyTopLeft()
		Blockman.instance:setKeyPressing("key.top.left", true)
		self:showMainControlTopLeftRight(true)
	end
	local function onReleaseKeyTopLeft()
		Blockman.instance:setKeyPressing("key.top.left", false)
		self:checkHideMainControlTopLeftRight()
    end
    
    local MainControl_top_left,MainControl_top_left_bg = self:child("MainControl-top-left"), self:child("MainControl-top-left-bg")
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_left event : EventWindowTouchDown", MainControl_top_left, UIEvent.EventWindowTouchDown, onPressKeyTopLeft)
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_left event : EventWindowTouchMove", MainControl_top_left, UIEvent.EventWindowTouchMove, onPressKeyTopLeft)
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_left event : EventMotionRelease", MainControl_top_left, UIEvent.EventMotionRelease, onReleaseKeyTopLeft)
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_left event : EventWindowTouchUp", MainControl_top_left, UIEvent.EventWindowTouchUp, onReleaseKeyTopLeft)
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_left_bg event : EventWindowTouchDown", MainControl_top_left_bg, UIEvent.EventWindowTouchDown, onPressKeyTopLeft)
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_left_bg event : EventWindowTouchMove", MainControl_top_left_bg, UIEvent.EventWindowTouchMove, onPressKeyTopLeft)
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_left_bg event : EventMotionRelease", MainControl_top_left_bg, UIEvent.EventMotionRelease, onReleaseKeyTopLeft)
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_left_bg event : EventWindowTouchUp", MainControl_top_left_bg, UIEvent.EventWindowTouchUp, onReleaseKeyTopLeft)

    local function onPressKeyTopRight()
		Blockman.instance:setKeyPressing("key.top.right", true)
		self:showMainControlTopLeftRight(true)
	end
	local function onReleaseKeyTopRight()
		Blockman.instance:setKeyPressing("key.top.right", false)
		self:checkHideMainControlTopLeftRight()
    end
    local MainControl_top_right,MainControl_top_right_bg = self:child("MainControl-top-right"), self:child("MainControl-top-right-bg")
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_right event : EventWindowTouchDown", MainControl_top_right, UIEvent.EventWindowTouchDown, onPressKeyTopRight)
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_right event : EventWindowTouchMove", MainControl_top_right, UIEvent.EventWindowTouchMove, onPressKeyTopRight)
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_right event : EventMotionRelease", MainControl_top_right, UIEvent.EventMotionRelease, onReleaseKeyTopRight)
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_right event : EventWindowTouchUp", MainControl_top_right, UIEvent.EventWindowTouchUp, onReleaseKeyTopRight)
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_right_bg event : EventWindowTouchDown", MainControl_top_right_bg, UIEvent.EventWindowTouchDown, onPressKeyTopRight)
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_right_bg event : EventWindowTouchMove", MainControl_top_right_bg, UIEvent.EventWindowTouchMove, onPressKeyTopRight)
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_right_bg event : EventMotionRelease", MainControl_top_right_bg, UIEvent.EventMotionRelease, onReleaseKeyTopRight)
    self:lightSubscribe("error!!!!! : win_actionControl MainControl_top_right_bg event : EventWindowTouchUp", MainControl_top_right_bg, UIEvent.EventWindowTouchUp, onReleaseKeyTopRight)

end

function M:initPoleControl()
    if worldCfg.isDragControl then
        return
    end
    self._wnd_poleBg = self:child("Main-PoleControl-bg")
	self._wnd_poleCenter = self:child("Main-PoleControl-Center")
    self._wnd_poleMove = self:child("Main-PoleControl-Move")
    
	self.originPolePosX = self._wnd_poleCenter:GetXPosition()
	self.originPolePosY = self._wnd_poleCenter:GetYPosition()
	local rect = self._wnd_poleCenter:GetUnclippedOuterRect()
	self.originPoleAbsPosX = rect[1] + self._wnd_poleCenter:GetPixelSize().x / 2
	self.originPoleAbsPosY = rect[2] + self._wnd_poleCenter:GetPixelSize().y / 2

    local function clearPoleDownTouchEndProp(self)
        if self.poleEndTouchEventListener then
            self.poleEndTouchEventListener()
            self.poleEndTouchEventListener = nil
        end
        self.poleDownTouchID = nil
    end

    self:lightSubscribe("error!!!!! : win_actionControl _wnd_poleMove event : EventWindowTouchDown", self._wnd_poleMove, UIEvent.EventWindowTouchDown, function()
        clearPoleDownTouchEndProp(self)
        self.poleDownTouchID = ti:getActiveTouch()
        self.poleEndTouchEventListener = Lib.lightSubscribeEvent("error!!!!! : win_actionControl lib event : EVENT_SCENE_TOUCH_END", Event.EVENT_SCENE_TOUCH_END, function(x, y, preX, preY, touchId)
            if not self.poleDownTouchID or touchId ~= self.poleDownTouchID then
                return
            end
            clearPoleDownTouchEndProp(self)
            self:onPoleTouchUp()
        end)
        self:onPoleTouchDown()
    end)

    self:lightSubscribe("error!!!!! : win_actionControl _wnd_poleMove event : EventWindowTouchMove", self._wnd_poleMove, UIEvent.EventWindowTouchMove, function(window, dx, dy)
        self:onPoleTouchMove(window, dx, dy)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl _wnd_poleMove event : EventWindowTouchUp", self._wnd_poleMove, UIEvent.EventWindowTouchUp, function()
        clearPoleDownTouchEndProp(self)
        self:onPoleTouchUp()
    end)

    self:lightSubscribe("error!!!!! : win_actionControl _wnd_poleMove event : EventMotionRelease", self._wnd_poleMove, UIEvent.EventMotionRelease, function()
        clearPoleDownTouchEndProp(self)
        self:onPoleTouchUp()
    end)

end

function M:initMainJump()
    self.mainJump = self:child("Main-Jump")
    
    if worldCfg.jumpIcon then
        self.mainJump:SetImage(worldCfg.jumpIcon)
    end

    self:lightSubscribe("error!!!!! : win_actionControl mainJump event : EventWindowTouchDown", self.mainJump, UIEvent.EventWindowTouchDown, function()
        Blockman.instance:setKeyPressing("key.jump", true)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl mainJump event : EventMotionRelease", self.mainJump, UIEvent.EventMotionRelease, function()
        Blockman.instance:setKeyPressing("key.jump", false)
    end)

    self:lightSubscribe("error!!!!! : win_actionControl mainJump event : EventWindowTouchUp", self.mainJump, UIEvent.EventWindowTouchUp, function()
        Blockman.instance:setKeyPressing("key.jump", false)
    end)

end

function M:init()
    WinBase.init(self, "ActionControl.json")
    initFlyBtn(self)
    if not CGame.instance:isShowPlayerControlUi() then
		self:isShownUi(CGame.instance:getPlatformId() ~= 1)
	end
    check2SetVisible(self, "Main-MoveState-Sneak", Me.movingStyle == 1)
    check2SetVisible(self, "Main-MoveState-Run", Me.movingStyle == 0)
    self:initMainJump()
    self:initJumpProgress()
    self:initStateControlConpoment()
    self:initDragControl()
    self:initPoleControl()
    self:initMoveControl()
    self:initSetting()
    Lib.lightSubscribeEvent("error!!!!! : win_actionControl lib event : EVENT_CHECKBOX_CHANGE", Event.EVENT_CHECKBOX_CHANGE, function(status)
		self:switchMoveControl(Blockman.instance.gameSettings.usePole)
		self:sneakBtnStatus()
    end)

	Lib.lightSubscribeEvent("error!!!!! : win_actionControl lib event : EVENT_SWITCH_MOVE_CONTROL", Event.EVENT_SWITCH_MOVE_CONTROL, function(usePole)
		self:switchMoveControl(usePole)
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_actionControl lib event : EVENT_SET_GUI_SIZE", Event.EVENT_SET_GUI_SIZE, function()
		self:updateGuiSize()
    end)
    self:switchMoveControl(Blockman.instance.gameSettings.usePole)
end

function M:customWindowArea(window, area)
    local TB, LR = area.VA or 0, area.HA or 0
    local VA = area.VAlign and v_alignment[area.VAlign] or (TB >= 0 and 0 or 2)
    local HA = area.HAlign and H_alignment[area.HAlign] or (LR >= 0 and 0 or 2)
    TB = VA == v_alignment.BOTTOM and TB > 0 and TB * -1 or TB
    LR = HA == H_alignment.RIGHT and LR > 0 and LR * -1 or LR
    if not window then
        return
    end
    window:SetVerticalAlignment(VA)
    window:SetHorizontalAlignment(HA)
    window:SetArea({ 0, LR }, { 0, TB }, { 0, area.W or area.width or 70 }, { 0, area.H or area.height or 70 })
end

function M:initSetting()
    self:sneakBtnStatus()
	self:updateGuiSize()
end

function M:updateMask(beginTime, endTime, iconCell, skillName, showInEnd)
    local mask = 1
    local upMask = 1 / ((endTime - beginTime) / 1)
    local function tick()
        if not iconCell then
            return false
        end
        mask = mask - upMask
        if mask <= 0 then
            iconCell:setMask(showInEnd and 0 or 1,0.5,0.5)
            check2SetVisible(self, iconCell, showInEnd or false)
            self.maskTimer[skillName] = nil
            return false
        end
        iconCell:setMask(mask,0.5,0.5)
        return true
    end
    self.maskTimer = self.maskTimer or {}
    self.maskTimer[skillName] = World.Timer(1, tick)
end

function M:fetchImageCell(imageName, areaTable, level, imagePath, visible, enableLongTouch, alwaysOnTop, name)
    local image = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", imageName)
    image:SetVerticalAlignment(2)
    image:SetHorizontalAlignment(2)
    image:SetArea(areaTable[1], areaTable[2], areaTable[3], areaTable[4])
    if level then
        image:SetLevel(level)
    end
    image:SetImage(imagePath or "")
    image:SetVisible(visible or false)
    image:setEnableLongTouch(enableLongTouch or false)
    image:SetAlwaysOnTop(alwaysOnTop or false)
    if name then
        image:SetName(name)
    end
    return image
end

local TopLeftRightRelatedKeys = {"key.forward", "key.top.left", "key.top.right"}
function M:checkHideMainControlTopLeftRight(isTimerCallback)
	if not isTimerCallback then
		self.hideControlTopLeftRightTimer = World.Timer(7, self.checkHideMainControlTopLeftRight, self, true)
		return
	end
	self.hideControlTopLeftRightTimer = nil
	local blockman = Blockman.instance
	for _, key in pairs(TopLeftRightRelatedKeys) do
		if blockman:isKeyPressing(key) then
			return
		end
	end
	self:showMainControlTopLeftRight(false)
end

function M:showMainControlTopLeftRight(show)
    check2SetVisible(self, "MainControl-top-left-bg", show)
    check2SetVisible(self, "MainControl-top-left", show)
    check2SetVisible(self, "MainControl-top-right-bg", show)
    check2SetVisible(self, "MainControl-top-right", show)
	local timer = self.hideControlTopLeftRightTimer
	if show and timer then
		timer()
		self.hideControlTopLeftRightTimer = nil
	end
end

function M:updateGuiSize()
    local mainControl = self:child("Main-Control")
	local width = Blockman.instance.gameSettings:getMainGuiWidth()
	local height = Blockman.instance.gameSettings:getMainGuiHeight()
	mainControl:SetWidth({width, 0})
	mainControl:SetHeight({height, 0})
	local size = Blockman.instance.gameSettings.playerActivityGuiSize
	self.mainJump:SetWidth({size, 0})
	self.mainJump:SetHeight({size, 0})
end

function M:switchMoveControl(isDefault)	
	if CGame.instance:getPlatformId() == 1 and (not(CGame.instance:isShowPlayerControlUi())) then   --if pc,then return
		return
	end

	local isUsePole = false
	if isDefault > 0 then
		isUsePole = true
	end
    --临时处理
    if worldCfg.isDragControl then
        check2SetVisible(self, "Main-Control", false)
        check2SetVisible(self, "Main-PoleControl", false)
        check2SetVisible(self, self.dragControl, true)
    else
        check2SetVisible(self, "Main-Control", isUsePole == false)
        check2SetVisible(self, "Main-PoleControl", isUsePole)
        check2SetVisible(self, self.dragControl, false)
    end
    if worldCfg.poleControlArea then
        self:child("Main-PoleControl"):SetArea(table.unpack(worldCfg.poleControlArea))
    end
	if isUsePole then
        check2SetVisible(self, "Main-Jump", true)
        check2SetVisible(self, "Main-Sneak", false)
	else 
		local isJumpDefault = Blockman.instance.gameSettings.isJumpSneakDefault > 0
		self:switchJumpSneak(isJumpDefault)
	end
    self:checkAlwaysHideBaseControl()
end

function M:onDragTouchDown(window, dx, dy)
    local points = self.dragPointContent
    local dragOriginX = screenToWindowX(points, dx)
    local dragOriginY = screenToWindowY(points, dy)
    self.dragScreenX = dx
    self.dragScreenY = dy
    self.dragOriginX = dragOriginX
    self.dragOriginY = dragOriginY
    local radius = points:GetPixelSize().x * 0.5
    local offsetX, offsetY = radius - dragOriginX, radius - dragOriginY
    local distance = math.sqrt(offsetX * offsetX + offsetY * offsetY)
    if distance > radius then
        return
    end
    self.inSide = true
    for _, point in ipairs(self.dragPoints) do
        local width = point:GetWidth()[2]
        point:SetXPosition({0, dragOriginX - 0.5 * width})
        point:SetYPosition({0, dragOriginY - 0.5 * width})
    end
    local winSize = self._root:GetPixelSize()
    check2SetVisible(self, points, true)
    if not self.originLevel then
        self.originLevel = self._root:GetLevel()
    end
    self._root:SetLevel(1)
    local dragControl = self.dragControl
    self.dragControlMove:SetArea({0, screenToWindowX(dragControl, dx) - dragAreaRadius}, {0, screenToWindowY(dragControl, dy) - dragAreaRadius}, {0, dragAreaSize}, {0, dragAreaSize})
    dragControl:SetImage(worldCfg.dragPushImage or "")
end

function M:onDragTouchMove(window, dx, dy)
    if not self.inSide then
        return
    end
	local offX = dx - self.dragScreenX
	local offY = dy - self.dragScreenY
	local disSqr = offX * offX + offY * offY
    disSqr = disSqr ~= 0 and disSqr or 1
	local poleForward = -offY / math.sqrt(disSqr)
	local poleStrafe = -offX / math.sqrt(disSqr)
    if Me:prop("forbidForwardControl") <= 0 then
        Blockman.instance.gameSettings.poleForward = poleForward
    end
	Blockman.instance.gameSettings.poleStrafe = poleStrafe
    local count = #self.dragPoints
    for i = 2, count do
        local point = self.dragPoints[i]
        local width = point:GetWidth()[2]
        point:SetXPosition({0, self.dragOriginX + offX / (count - 1) * (i - 1) - 0.5 * width})
        point:SetYPosition({0, self.dragOriginY + offY / (count - 1) * (i - 1) - 0.5 * width})
    end
    self.dragControlMove:SetArea({0, screenToWindowX(self.dragControl, dx) - dragAreaRadius}, {0, screenToWindowY(self.dragControl, dy) - dragAreaRadius}, {0, dragAreaSize}, {0, dragAreaSize})
end

function M:onDragTouchUp()
    self.inSide = false
    self.dragControlMove:SetArea({0, 0}, {0, 0}, {1+dragAreaOffset, 0}, {1+dragAreaOffset, 0})
    check2SetVisible(self, self.dragPointContent, false)
    if self.originLevel then
        self._root:SetLevel(self.originLevel)
    end
    self.dragControl:SetImage(worldCfg.dragNormalImage or "")
    if Me:prop("forbidForwardControl") <= 0 then
        Blockman.instance.gameSettings.poleForward = 0
    end
	Blockman.instance.gameSettings.poleStrafe = 0
end

function M:onPoleTouchDown()
	self._wnd_poleMove:SetArea({0, -50}, {-1.25, 70}, {2, 0}, {2.25, 0})
	self._wnd_poleBg:SetAlpha(0.5)
end

function M:onPoleTouchMove(window, dx, dy)
	local fMaxDis = worldCfg.poleCenterMaxDis or 25.0
	local offX = dx - self.originPoleAbsPosX
	local offY = dy - self.originPoleAbsPosY
	local disSqr = offX * offX + offY * offY
    disSqr = disSqr ~= 0 and disSqr or 1
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
    if Me:prop("forbidForwardControl") <= 0 then
        Blockman.instance.gameSettings.poleForward = poleForward
    end
	Blockman.instance.gameSettings.poleStrafe = poleStrafe
end

function M:onPoleTouchUp()
	self._wnd_poleMove:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
	self._wnd_poleCenter:SetXPosition(self.originPolePosX)
	self._wnd_poleCenter:SetYPosition(self.originPolePosY)
	self._wnd_poleBg:SetAlpha(1)
    if Me:prop("forbidForwardControl") <= 0 then
        Blockman.instance.gameSettings.poleForward = 0
    end
	Blockman.instance.gameSettings.poleStrafe = 0
end

function M:switchJumpSneak(isDefault)
    if worldCfg.alwaysHideSneak then
        check2SetVisible(self, "MainControl-sneak", false)
        check2SetVisible(self, "Main-Sneak", false)
        check2SetVisible(self, "Main-Jump", true)
        check2SetVisible(self, "MainControl-jump", true)
        return
    end
	if self:isHideSneakBtn() then      --todo 配置sneak
        check2SetVisible(self, "MainControl-sneak", isDefault)
        check2SetVisible(self, "Main-Sneak", not isDefault)
	end
    check2SetVisible(self, "Main-Jump", isDefault)
    check2SetVisible(self, "MainControl-jump", not isDefault)
end

function M:isHideSneakBtn()   --to do
	return true
end

function M:sneakBtnStatus()   --to do
	local isSneakPressed = Blockman.instance:isKeyPressing("key.sneak")
	if  isSneakPressed then
		self:child("Main-Sneak"):SetAlpha(0.6)
		self:child("MainControl-sneak"):SetAlpha(0.6)
	else
		self:child("Main-Sneak"):SetAlpha(0.9)
		self:child("MainControl-sneak"):SetAlpha(0.9)
	end
end

function M:isShownUi(on)
	if CGame.instance:getPlatformId() ~= 1 then
		return
	end
    check2SetVisible(self, "Main-MoveState", on)
    check2SetVisible(self, "Main-Control", on)
    check2SetVisible(self, "Main-Jump-Controls", on)
    check2SetVisible(self, "Main-PoleControl", on)
    self:checkAlwaysHideBaseControl()
end

function M:checkAlwaysHideBaseControl()
    if World.cfg.alwaysHideBaseControl then 
        check2SetVisible(self, "Main-MoveState", false)
        check2SetVisible(self, "Main-Jump-Controls", false)
        check2SetVisible(self, "Main-Control", false)
        check2SetVisible(self, "Main-PoleControl", false)
        check2SetVisible(self, "Main-DragControl", false)
    end
end

return M
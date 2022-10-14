local M = UI:getWnd("actionControl")

local worldCfg = World.cfg
local screenToWindowX = CoordConverter.screenToWindowX1
local screenToWindowY = CoordConverter.screenToWindowY1
local dragAreaSize = worldCfg.dragAreaSize or 200
local dragAreaRadius = dragAreaSize / 2

local function checkMove(self, content, window, dx, dy)
    if not self.inSide then
        return
    end
    local size = content:GetPixelSize()
    local centerX = size.x * 0.5
    local centerY = size.y * 0.5
    local curX = screenToWindowX(content, dx)
    local curY = screenToWindowY(content, dy)
	local offX = curX - centerX
	local offY = curY - centerY
	local disSqr = offX * offX + offY * offY
    disSqr = disSqr ~= 0 and disSqr or 1
	local poleForward = -offY / math.sqrt(disSqr)
	local poleStrafe = -offX / math.sqrt(disSqr)
	Blockman.instance.gameSettings.poleForward = poleForward
	Blockman.instance.gameSettings.poleStrafe = poleStrafe
    local count = #self.dragPoints
    for i = 1, count do
        local point = self.dragPoints[i]
        local width = point:GetWidth()[2]
        point:SetXPosition({0, centerX + offX / (count - 1) * (i - 1) - 0.5 * width})
        point:SetYPosition({0, centerY + offY / (count - 1) * (i - 1) - 0.5 * width})
        point:SetRotate(90 + math.atan(offY , offX) * 180 / math.pi)
    end
    self.dragControlMove:SetArea({0, screenToWindowX(self.dragControl, dx) - dragAreaRadius}, {0, screenToWindowY(self.dragControl, dy) - dragAreaRadius}, {0, dragAreaSize}, {0, dragAreaSize})
end

function M:resetControl()
    local size = {13, 19, 22, 60}
    for _, point in ipairs(self.dragPoints) do
        local parent = point:GetParent()
        if parent then
            parent:RemoveChildWindow1(point)
        end
    end
    self.dragPoints = {}
    for i = 1, 4 do
        local radius = size[i]
        local point = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "DragControl-Point" .. i)
        point:SetArea({0, 0}, {0, 0}, {0, radius}, {0, radius})
        point:SetTouchable(false)
        point:SetImage("set:direction_control.json image:drag_point_" .. i .. ".png")
        self.dragPointContent:AddChildWindow(point)
        table.insert(self.dragPoints, point)
    end

    self:unsubscribe(self.dragControlMove)
    self:subscribe(self.dragControlMove, UIEvent.EventWindowTouchDown, function(window, dx, dy)
        self:onDragTouchDown(window, dx, dy)
    end)

    self:subscribe(self.dragControlMove, UIEvent.EventWindowTouchMove, function(window, dx, dy)
        self:onDragTouchMove(window, dx, dy)
    end)

    self:subscribe(self.dragControlMove, UIEvent.EventWindowTouchUp, function()
        self:onDragTouchUp()
    end)

    self:subscribe(self.dragControlMove, UIEvent.EventMotionRelease, function()
        self:onDragTouchUp()
    end)
end

function M:onDragTouchDown(window, dx, dy)
    local points = self.dragPointContent
    local dragOriginX = screenToWindowX(points, dx)
    local dragOriginY = screenToWindowY(points, dy)
    local radius = points:GetPixelSize().x * 0.5
    local offsetX, offsetY = radius - dragOriginX, radius - dragOriginY
    local distance = math.sqrt(offsetX * offsetX + offsetY * offsetY)
    if distance > radius then
        return
    end
    self.inSide = true
    points:SetVisible(true)
    if not self.originLevel then
        self.originLevel = self._root:GetLevel()
    end
    self._root:SetLevel(1)
    local dragControl = self.dragControl
    self.dragControlMove:SetArea({0, screenToWindowX(dragControl, dx) - dragAreaRadius}, {0, screenToWindowY(dragControl, dy) - dragAreaRadius}, {0, dragAreaSize}, {0, dragAreaSize})
    dragControl:SetImage(worldCfg.dragPushImage or "")
    checkMove(self, points, window, dx, dy)
end

function M:onDragTouchMove(window, dx, dy)
    checkMove(self, self.dragPointContent, window, dx, dy)
end

function M:onDragTouchUp()
    self.inSide = false
	self.dragControlMove:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
    self.dragPointContent:SetVisible(false)
    if self.originLevel then
        self._root:SetLevel(self.originLevel)
    end
    self.dragControl:SetImage(worldCfg.dragNormalImage or "")
    Blockman.instance.gameSettings.poleForward = 0
	Blockman.instance.gameSettings.poleStrafe = 0
end

function M:switchMoveControl(isDefault)	
	if CGame.instance:getPlatformId() == 1 and (not(CGame.instance:isShowPlayerControlUi())) then   --if pc,then return
		return
	end

	local isUsePole = false
	if isDefault > 0 then
		isUsePole = true
	end

    self:child("Main-Control"):SetVisible(not isUsePole)
    self:child("Main-PoleControl"):SetVisible(false)
    self.dragControl:SetVisible(isUsePole)

    if worldCfg.poleControlArea then
        self.dragControl:SetArea(table.unpack(worldCfg.poleControlArea))
    end
	if isUsePole then
		self:child("Main-Jump"):SetVisible(true)
		self:child("Main-Sneak"):SetVisible(false)
	else 
		local isJumpDefault = Blockman.instance.gameSettings.isJumpSneakDefault > 0
		self:switchJumpSneak(isJumpDefault)
	end
    self:checkAlwaysHideBaseControl()
end

M:resetControl()
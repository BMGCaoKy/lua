local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)
local windowToScreenX = CoordConverter.windowToScreenX1
local windowToScreenY = CoordConverter.windowToScreenY1
local editData = nil
local listenTypes = {
	onTextChange = "onTextChange",
	onFinishTextChange = "onFinishTextChange"
}

function M:init()
	widget_base.init(self, "slider_edit.json")
	self.editUI = self:child("Slider-Edit")
	self.editMask = self:child("Slider-Mask")
	self.sliderUI = self:child("Slider-Item-1")
	self.slidContainer = self:child("Slider-Item")
	self.titleUI = self:child("Slider-Name")
	self.unitUI = self:child("Slider-unit")
	self.helpUI = self:child("Slider-help")
	self.editUI:SetTextVertAlign(1)
	self.editUI:SetTextHorzAlign(1)
	self.editUI:SetTextColor({0,0,0,1})
end

function M:setSliderUiOffsetX(offset)
	local sliderUiItem = {
		self.unitUI,
		self.helpUI,
		self:child("Slider-edit_bg"),
		self.slidContainer
	}
	for _, ui in pairs(sliderUiItem) do
		local selfOffsetX = ui:GetXPosition()[2]
		ui:SetXPosition({0, selfOffsetX + offset})
	end
end

function M:setUIText()
	if not self.sliderCsvData then
		return
	end
	local sliderCsvData = self.sliderCsvData
	local titleText = sliderCsvData.title and Lang:toText(sliderCsvData.title) or ""
	self.titleUI:setTextAutolinefeed(titleText)
	self.titleUI:SetWordWrap(true)
	self.unitUI:SetWordWrap(true)
	if World.Lang == "ru" then
		self.titleUI:SetFontSize("HT16")
		self.unitUI:SetFontSize("HT14")
	end
	local tailText = sliderCsvData.tailText and Lang:toText(sliderCsvData.tailText) or ""
	self.unitUI:setTextAutolinefeed(tailText)
	self:textSizeToUISize()
end

function M:textSizeToUISize()
    local height = self.titleUI:GetTextStringHigh()
    self._root:SetHeight({0, height + 20})
end

function M:setProgressUI(value)
    self.sliderUI:SetProgress(value)
    self.slidContainer:SetProgress(value)
end

function M:getProgressUI()
    return self.sliderUI:GetProgress()
end

function M:setEditValueUI(value)
    if value and value ~= "--" then
        value = self:judgeData(tonumber(value))
        editData = value
    end
	self.editUI:SetText(Lang:toText(value))
    if self.hub then
        self.hub:child("Num"):SetText(value)
    end
end

function M:progressToValue(progress)
	local sliderCsvData = self.sliderCsvData
	local ranges = sliderCsvData.range
	local rangeCount = ranges and #ranges or 0
	local baseProgress = 1 / rangeCount
	local resultValue = 0

	if sliderCsvData.infinity and progress >= 0.99 then
		return tonumber(ranges[rangeCount][2]), true
	end
	for i = 1, rangeCount do
		local range = ranges[i]
		local maxValue = tonumber(range[2])
		local minValue = tonumber(range[1])
		local rangeSize = maxValue - minValue
		local scale = tonumber(sliderCsvData.scale[i])
		if baseProgress * i  >  progress then
			local addResult = ranges[i][1]
			local lastProgress = (i - 1) * baseProgress
			local offsetProgress = (progress - lastProgress) / baseProgress
            resultValue = addResult + math.floor(offsetProgress * rangeSize / scale + 0.5) * scale
			return tonumber(resultValue), false
		end
	end
	return tonumber(ranges[rangeCount][2]), false
end

function M:valueToProgress(value)
	local sliderCsvData = self.sliderCsvData
	if not value then
		return 1
	end
	local ranges = sliderCsvData.range
	local rangeCount = ranges and #ranges or 0
	local baseProgress = 1 / rangeCount
	local result = 0
	for i = 1, rangeCount do
		local range = ranges[i]
		local maxValue = tonumber(range[2])
		local minValue = tonumber(range[1])
		local scale = tonumber(sliderCsvData.scale[i])
		local scaleCount =  math.ceil((maxValue - minValue) / scale)
		
		if value > maxValue then
			result = baseProgress * i
		elseif value == maxValue then
			return baseProgress * i
		else
			local addResult = baseProgress / scaleCount * math.floor((value - minValue) /  scale)
			result = result + addResult
			return result
		end
	end
	return 1
end

function M:setUIValue(value)
	if not self.sliderCsvData then
		return
	end
	if value then
		value = self:judgeData(tonumber(value))
		local cmpValue, isInfinity = self:progressToValue(1.0)
		self:setEditValueUI(value >= cmpValue and cmpValue or value)
		local progress = self:valueToProgress(value)
		self.sliderUI:SetProgress(progress)
		self.slidContainer:SetProgress(progress)
	end
end

function M:judgeData(value)
    local data = self.sliderCsvData
    local isFloat = data.isFloat
    local minValue = tonumber(data.range[1][1]) or 0
    local maxValue = tonumber(data.range[data.rangeCount][2]) or minValue
    if not isFloat then
        value = math.floor(value)
    end
    if value < minValue then
        value = minValue
    elseif value > maxValue then
        value = maxValue
    end
    return value
end

function M:callBackFunc(value, isInfinity)
	local convert = self.sliderCsvData.convert or 1
	if self.backFunc then
		self.backFunc(value * convert, isInfinity)
	end
end

local function updateHubble(self, progress)
	if not self.enableHubble or not self.hub then
		return
	end
    local width = self.sliderUI:GetPixelSize().x
    local x = windowToScreenX(self.sliderUI, width * progress)
    local y = windowToScreenY(self.sliderUI, 0)
    self.hub:SetXPosition({0, x - 40})
    self.hub:SetYPosition({0, y - 75})
end

local function createHubble(self)
    if not self.enableHubble or self.hub then
        return
    end
    local hub = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Hubble")
    hub:SetArea({0, 0}, {0, 0}, {0, 80}, {0, 66})
    hub:SetLevel(0)
    hub:SetImage("set:setting_global.json image:bg_hubble.png")
    local num = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Num")
    num:SetArea({0, 0}, {0, 0}, {1, 0}, {0.85, 0})
    num:SetTextHorzAlign(1)
    num:SetTextVertAlign(1)
    hub:AddChildWindow(num)
    self.hub = hub
    GUISystem.instance:GetRootWindow():AddChildWindow(self.hub)
end

local function removeHubble(self)
    if self.hub then
        GUISystem.instance:GetRootWindow():RemoveChildWindow1(self.hub)
        self.hub = nil
    end
end

local function updateUI(self, progress, listenType)
    local value, isInfinity = self:progressToValue(progress)
    self.sliderUI:SetProgress(progress)
    self:setEditValueUI(value)
    updateHubble(self, progress)
    if self.listenType == listenType then
        self:callBackFunc(value, isInfinity)
    end
end

local function calculateProgress(self, containWidth, slidWidth, slidLeft, slidRight, listenType)
    local xOff = self.slidContainer:GetProgress() * containWidth
    local realXOff
    if xOff < slidLeft then
        realXOff = 0
    elseif xOff > slidRight then
        realXOff = slidWidth
    else
        realXOff = xOff - slidLeft
    end
    local realPro = realXOff / slidWidth
    updateUI(self, realPro, listenType)
end

function M:uiEventReg()
    if not self.sliderCsvData then
        return
    end
    local sliderCsvData = self.sliderCsvData
    local slider = self.sliderUI
    local container = self.slidContainer
    local edit = self.editUI
    local help = self.helpUI

    local containWidth = container:GetPixelSize().x
    local slidWidth = slider:GetPixelSize().x
    local slidLeft = (containWidth - slidWidth) * 0.5
    local slidRight = slidLeft + slidWidth
    container:subscribe(UIEvent.EventWindowTouchDown, function()
        createHubble(self)
        calculateProgress(self, containWidth, slidWidth, slidLeft, slidRight, listenTypes.onTextChange)
    end)
    container:subscribe(UIEvent.EventWindowTouchMove, function()
        calculateProgress(self, containWidth, slidWidth, slidLeft, slidRight, listenTypes.onTextChange)
    end)
    container:subscribe(UIEvent.EventWindowTouchUp, function()
        calculateProgress(self, containWidth, slidWidth, slidLeft, slidRight, listenTypes.onFinishTextChange)
        removeHubble(self)
    end)
    container:subscribe(UIEvent.EventMotionRelease, function()
        calculateProgress(self, containWidth, slidWidth, slidLeft, slidRight, listenTypes.onFinishTextChange)
        removeHubble(self)
    end)
	
    edit:subscribe(UIEvent.EventWindowTouchUp,function()
        local numpad = UI:openWnd("mapEditNumpad")
        local x = windowToScreenX(edit, 0)
        local y = windowToScreenY(edit, 0)
        numpad:setEditWnd( edit, self, self.sliderCsvData.isFloat, x, y )
    end)

	local helpContent = sliderCsvData.helpContent
	if helpContent then
		help:subscribe(UIEvent.EventButtonClick, function()
			UILib.openDialog(Lang:toText(helpContent))
		end)
	else
		help:SetVisible(false)
	end
end

function M:onEditValueChanged(value)
	value = tonumber(value)
	local data = self.sliderCsvData
	local minValue = tonumber(data.range[1][1]) or 0
	local maxValue = tonumber(data.range[data.rangeCount][2]) or minValue
	if not value or value < minValue then
		Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("win.slider.edit.set.min"), 20)
	elseif value > maxValue then
		Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("win.slider.edit.set.max"), 20)
	end
	if value then
		editData = value
		value = self:judgeData(value)
		local cmpValue, isInfinity = self:progressToValue(1.0)
		self:setEditValueUI(value >= cmpValue and cmpValue or value)
		local progress = self:valueToProgress(value)
		self.sliderUI:SetProgress(progress)
		self.slidContainer:SetProgress(progress)
		self:callBackFunc(value >= cmpValue and cmpValue or value, value >= cmpValue and isInfinity)
	else
		local bar = slider:GetProgress()
		local value, isInfinity = self:progressToValue(bar)
		if editData then
			value = editData
		end
		self:setEditValueUI(isInfinity and "--" or value)
	end
end

function M:fillData(params)
    local cfg = Clientsetting.getUIDescCsvData(params.index)
    if not cfg then
        return
	end
	self.listenType = params.listenType or listenTypes.onTextChange
	self.sliderCsvData = cfg
	local convert = self.sliderCsvData.convert or 1
	local value = params.value and params.value / convert
	self.enableHubble = self.sliderCsvData.enableHubble
	self:setUIText()
	self:setUIValue(value)
	self:uiEventReg()
end

function M:setBackFunc(func)
	self.backFunc = func
end

function M:cmp(item1, item2)
	if item1.index and item1.index == item2.index then
		return true
	end
	return false
end

return M

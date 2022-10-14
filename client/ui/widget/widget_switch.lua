local widget_base = require "ui.widget.widget_base"

local M = Lib.derive(widget_base)
function M:init()
	widget_base.init(self, "onOff_edit.json")
	self:initUIName()
end

function M:initUIName()
    self.textUI = self:child("Offon-Name")
	self.checkBtn = self:child("Offon-CheckBox")
	self.posUI = self:child("Offon-root")
end

function M:setSliderUiOffsetX(offset)
	self.checkBtn:SetXPosition({0, self.checkBtn:GetXPosition()[2] + offset})
end

function M:textSizeToUISize()
    local height = self.textUI:GetTextStringHigh()
    height = height < 50 and 50 or height
    self._root:SetHeight({0, height})
end

function M:setPos(x, y)
	if x then
		self.posUI:SetXPosition(x)
	end
	if y then
		self.posUI:SetYPosition(y)
	end
end

function M:cmp(item1, item2)
	if item1.index and item1.index == item2.index then
		return true
	end
	return false
end

function M:fillData(params)
    local cfg = Clientsetting.getUIDescCsvData(params.index)
    if not cfg then
        return
	end
	self.csvData = cfg
	local value = params.value
    self:setUIText()
    self:setUIValue(value)
    self:setHelpUI()
    self:regEvent()
end

function M:setBackFunc(backFunc)
    self.backFunc = backFunc
end

function M:setUIText()
    local csvData = self.csvData
    if not csvData then
        return
    end
    local title = csvData.title
    self.textUI:setTextAutolinefeed(Lang:toText(title))
    self.textUI:SetWordWrap(true)
    self.textUI:SetTextVertAlign(1)
    if World.Lang == "ru" then
        self.textUI:SetFontSize("HT16")
    end
    self:textSizeToUISize()
end

function M:setUIValue(value)
    self.checkBtn:SetChecked(value and true or false)
end

function M:setTextUiSize(size)
    self.textUI:SetFontSize("HT" .. size)
end

function M:setHelpUI()
    
end

function M:regEvent()
    local checkBtn = self.checkBtn
    checkBtn:subscribe(UIEvent.EventCheckStateChanged, function(status)
        local func = self.backFunc
        if func then
            func(status:GetChecked())
        end
	end)
end

return M
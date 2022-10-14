local widget_base = require "ui.widget.widget_base"

local M = Lib.derive(widget_base)
local isEmitEvent = true

function M:init()
    widget_base.init(self, "moveBlockconfig_edit.json")
    self:initUiName()
    self.num1 = 1
    self.num2 = 1
    self.num3 = 1

	self.xText:SetText(Lang:toText("length"))
	self.zText:SetText(Lang:toText("width"))
	self.yText:SetText(Lang:toText("height"))
	self.title:SetText(Lang:toText("MoveBlockSize"))

    self:updataNum()
    self:subscribe(self.sub1, UIEvent.EventButtonClick, function()
        self.num1 = self.num1 - 1 > 0 and self.num1 - 1 or 1
        self:updataNum()
    end)
    self:subscribe(self.sub2, UIEvent.EventButtonClick, function()
        self.num2 = self.num2 - 1 > 0 and self.num2 - 1  or 1
        self:updataNum()
    end)
    self:subscribe(self.sub3, UIEvent.EventButtonClick, function()
        self.num3 = self.num3 - 1 > 0 and self.num3 - 1 or 1
        self:updataNum()
    end)

    self:subscribe(self.add1, UIEvent.EventButtonClick, function()
        self.num1 = self.num1 + 1
		self.num1 = self.num1 > 20 and 20 or self.num1
        self:updataNum()
        if isEmitEvent then
            Lib.emitEvent(Event.EVENT_NOVICE_GUIDE,1)
            isEmitEvent = false
        end 
    end)
    self:subscribe(self.add2, UIEvent.EventButtonClick, function()
        self.num2 = self.num2 + 1
		self.num2 = self.num2 > 20 and 20 or self.num2
        self:updataNum()
    end)
    self:subscribe(self.add3, UIEvent.EventButtonClick, function()
        self.num3 = self.num3 + 1 
		self.num3 = self.num3 > 20 and 20 or self.num3
        self:updataNum()    
    end)
end

function M:updataNum()
    self.num1Text:SetText(string.format( "%d", self.num1))
    self.num2Text:SetText(string.format( "%d", self.num2))
    self.num3Text:SetText(string.format( "%d", self.num3))
    print("updataNum")

end

function M:getX()
    return self.num1
end

function M:getY()
    return self.num2
end

function M:getZ()
    return self.num3
end

function M:getSize()
    return {self:getX(), self:getY(), self:getZ()}
end

function M:setSize(table)
    self.num1 = table[1]
    self.num2 = table[2]
    self.num3 = table[3]
end

function M:initUiName()
    self.sub1 = self:child("mapEditItemBagRoot-btnSub")
    self.add1 = self:child("mapEditItemBagRoot-btnAdd")
    self.num1Text = self:child("mapEditItemBagRoot-textCount")

    self.sub2 = self:child("mapEditItemBagRoot-btnSub_12")
    self.add2 = self:child("mapEditItemBagRoot-btnAdd_15")
    self.num2Text = self:child("mapEditItemBagRoot-textCount_13")

    self.sub3 = self:child("mapEditItemBagRoot-btnSub_17")
    self.add3 = self:child("mapEditItemBagRoot-btnAdd_20")
    self.num3Text = self:child("mapEditItemBagRoot-textCount_18")

	self.xText = self:child("mapEditItemBagRoot-label_1")
	self.yText = self:child("mapEditItemBagRoot-label_1_22")
	self.zText = self:child("mapEditItemBagRoot-label_1_23")
	self.title = self:child("mapEditItemBagRoot-title_c")
end

return M

--[[
轻量通用adapter,，使用时传宽，高，widget名称，json名称即可，可以不用单独创建一个adapter
举例--self.bagAdapter = UIMgr:new_adapter("common", itemWidth, itemWidth,Define.WIDGET_NAME.punkItemBagCell,"PunkItemBagCell.json")

]]

local adapter_base = require "ui.adapter.adapter_base"
local M = Lib.derive(adapter_base)

function M:init(width, height,widgetName,jsonName)
    adapter_base.init(self)
    self.width = width
    self.height = height
    self.widthData = { 0, self.width }
    self.heightData = { 0, self.height }
    self.widgetName = widgetName
    self.jsonName = jsonName
end

function M:getWidgetName()
    return self.widgetName
end

function M:getJsonName()
    return self.jsonName
end

function M:getItemWidth()
    return self.widthData
end

function M:getItemHeight()
    return self.heightData
end

return M
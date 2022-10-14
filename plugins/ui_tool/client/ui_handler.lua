---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by 10184.
--- DateTime: 2022/5/23 15:05
---
---@class UITool
local UITool = T(UILib, "UITool")
---@type CEGUILayout[]
UITool.windows = {}
---@type CEGUILayout[]
UITool.delayShowWins = {}
---@type string[]
UITool.writeList = {}
UITool.isHideAllWin = false

local SceneUISession = 0
local function allowSceneUISession()
    SceneUISession = SceneUISession + 1
    return SceneUISession
end

function UITool:getWindow(module, name)
    local key = module .. ":" .. name
    return self.windows[key]
end

function UITool:openWindow(module, name, ...)
    local window = self:getWindow(module, name)
    if window then
        return window
    end
    local key = module .. ":" .. name
    local layout = string.format("UI/%s/window/%s", module, name)
    window = UI:openWindow(layout, layout, "asset", ...)
    if not window then
        Lib.logWarning("[ui_tool]:UITool:openWindow failed. can't find window : " .. layout)
        return
    end
    window.close = function(...)
        self:closeWindow(module, name, ...)
    end
    self.windows[key] = window
    if self.isHideAllWin and not Lib.tableContain(self.writeList, layout) then
        window:hide()
        self.delayShowWins[key] = window
    end
    return window
end

function UITool:closeWindow(module, name, ...)
    local window = self:getWindow(module, name)
    if not window then
        return
    end
    local key = module .. ":" .. name
    self.delayShowWins[key] = nil
    self.windows[key] = nil
    UI:closeWindow(window, ...)
end

function UITool:isOpenWindow(module, name)
    local window = self:getWindow(module, name)
    if not window then
        return false
    end
    if window:isVisible() then
        return window
    end
    return false
end

function UITool:openWidget(module, name, ...)
    local widgetName = string.format("UI/%s/widget/%s", module, name)
    return UI:openWidget(widgetName, "asset", ...)
end

function UITool:openSceneWindow(module, name, args, ...)
    local windowName = string.format("UI/%s/widget/%s", module, name)
    local instanceName = "SceneWindow-" .. allowSceneUISession()
    local sceneWindow, instance = UI:openSceneWindow(windowName, instanceName, args, "asset", ...)
    return sceneWindow, instance, instanceName
end

---添加显示白名单
function UITool:addHideWriteWnd(module, name)
    local layout = string.format("UI/%s/window/%s", module, name)
    self.writeList = self.writeList or {}
    if Lib.tableContain(self.writeList, layout) then
        return
    end
    table.insert(self.writeList, layout)
end

function UITool:hideAllWindow(writeList)
    self.isHideAllWin = true
    self.writeList = writeList
    if self.showWinFunc then
        self.showWinFunc()
        self.showWinFunc = nil
    end
    self.showWinFunc = UI:hideAllWindow(writeList)
end

function UITool:showAllWindow()
    self.isHideAllWin = false
    if self.showWinFunc then
        self.showWinFunc()
        self.showWinFunc = nil
    end
    for _, win in pairs(self.delayShowWins) do
        win:show()
    end
    self.delayShowWins = {}
end
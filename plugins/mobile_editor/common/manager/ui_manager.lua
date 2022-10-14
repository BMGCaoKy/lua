--- ui_manager.lua
--- ui的管理器
---@class UIManager : singleton
local UIManager = T(MobileEditor, "UIManager")

function UIManager:initialize()
    ---@type CEGUILayout[]
    self.windows = {}
    self:subscribeEvents()
end

function UIManager:initMainUI()
    self:openWindow("mobile_editor", "mobile_editor_main")
    self:openWindow("new_mobile_editor", "main")


    self.gizmoMoveUIPath = "UI/new_mobile_editor/gui/window/scene_gizmo_move"
    self.gizmoRotateUIPath = "UI/new_mobile_editor/gui/window/scene_gizmo_rotate"
    self.gizmoScaleUIPath = "UI/new_mobile_editor/gui/window/scene_gizmo_scale"

    local args = {
        position = Vector3.new(0, 31.5, 0),
        rotation = Vector3.new(0, 0, 0),
        width = 0.5,
        height = 0.5,
        flags = 10,
        objID = 0,
    }

    self.sceneGizmoMove = UI:openSceneWindow(self.gizmoMoveUIPath, nil, args, "asset")
    self.sceneGizmoRotate = UI:openSceneWindow(self.gizmoRotateUIPath, nil, args, "asset")
    self.sceneGizmoScale = UI:openSceneWindow(self.gizmoScaleUIPath, nil, args, "asset")
end

function UIManager:finalize()
    UI:closeSceneWindow(self.gizmoMoveUIPath)
    UI:closeSceneWindow(self.gizmoRotateUIPath)
    UI:closeSceneWindow(self.gizmoScaleUIPath)
end

function UIManager:subscribeEvents()
    Lib.subscribeEvent(Event.EVENT_SHOW_WINDOW, function(windowName)
        local window = UI:isOpenWindow(windowName)
        if window then
            window:setVisible(true)
            window:setEnabled(true)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_HIDE_WINDOW, function(windowName)
        local window = UI:isOpenWindow(windowName)
        if window then
            window:setVisible(false)
            window:setEnabled(false)
        end
    end)

    Lib.subscribeEvent(Event.EVENT_SHOW_NOTIFICATION, function(content)
        ---@type MobileEditorTipLayout
        local window = self:openWindow("mobile_editor", "mobile_editor_tip")
        window:setContent(content)
    end)
end

function UIManager:openWindow(module, name, ...)
    local layout = string.format("UI/%s/gui/window/%s", module, name)
    local window = UI:openWindow(layout, nil, "layouts", ...)
    self.windows[module .. ":" .. name] = window
    return window
end

function UIManager:getWindow(module, name)
    return self.windows[module .. ":" .. name]
end

function UIManager:openWidget(module, name, ...)
    local widgetName = string.format("UI/%s/gui/widget/%s", module, name)
    return UI:openWidget(widgetName, "widgets", ...)
end

function UIManager:closeWindow(module, name)
    local window = self:getWindow(module, name)
    if not window then
        return
    end
    window.close()
end

return UIManager
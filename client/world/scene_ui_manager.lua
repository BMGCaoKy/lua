local self = SceneUIManager

local function refreshWindow(key, openParams)
    local wnd = UI._windows[key]
    if wnd then
        wnd:onOpen(openParams)
    end
end

function SceneUIManager.AddSceneUI(key, uiData)
    local uiCfg = uiData.uiCfg
    UI:openSceneWnd(key, uiCfg.name, uiCfg.width, uiCfg.height, uiCfg.rotate, uiCfg.position, uiData.openParams)
end

function SceneUIManager.RemoveSceneUI(key)
    UI:closeSceneWnd(key)
end

function SceneUIManager.RefreshSceneUI(key, openParams)
    refreshWindow(key, openParams)
end

function SceneUIManager.ShowAllSceneUI(curMapUI)
    for key, uiData in pairs(curMapUI) do
        if UI._windows[key] then--already have the window
            goto continue
        end
        self.AddSceneUI(key, uiData)
        ::continue::
    end
end

function SceneUIManager.CloseAllSceneUI(curMapUI)
    for key in pairs(curMapUI) do
        self.RemoveSceneUI(key)
    end
end

function SceneUIManager.AddEntityHeadUI(objID, headUI)
    local uiCfg = headUI.uiCfg
    UI:openHeadWnd(objID, uiCfg.name, uiCfg.width, uiCfg.height, headUI.openParams)
end

function SceneUIManager.RemoveEntityHeadUI(objID)
    UI:closeHeadWnd(objID)
end

function SceneUIManager.RefreshEntityHeadUI(objID, openParams)
    local key = "*head_" .. objID
    refreshWindow(key, openParams)
end

function SceneUIManager.AddEntitySceneUI(objID, key, uiData)
    local uiCfg = uiData.uiCfg
    UI:openEntitySceneWnd(key, uiCfg.name, uiCfg.width, uiCfg.height, uiCfg.rotate, uiCfg.position, objID, uiData.openParams)
end

function SceneUIManager.RemoveEntitySceneUI(key)
    UI:closeSceneWnd(key)
end

function SceneUIManager.RefreshEntitySceneUI(key, openParams)
    refreshWindow(key, openParams)
end

function SceneUIManager.InitEntityUI(objID, entityUI)
    local headUI = entityUI.headUI
    if headUI then
        self.AddEntityHeadUI(objID, headUI)
    end
    local sceneUI = entityUI.sceneUI
    if sceneUI and next(sceneUI) then
        for key, uiData in pairs(sceneUI) do
            self.AddEntitySceneUI(objID, key, uiData)
        end
    end
end

function SceneUIManager.RemoveEntityUI(objID, entityUI)
    if entityUI.headUI then
        self.RemoveEntityHeadUI(objID)
    end
    local sceneUI = entityUI.sceneUI
    if sceneUI and next(sceneUI) then
        for key in pairs(sceneUI) do
            self.RemoveEntitySceneUI(key)
        end
    end
end

RETURN(SceneUIManager)

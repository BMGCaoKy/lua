local shortMgr = require "editor.module.shortClick.shortMgr"
local editorEventSolve = L("editorEventSolve", Lib.derive(EditorModule.baseDerive))
local eventFunc = L("eventFunc", Lib.derive(EditorModule.baseDerive))
local bm = Blockman.Instance()

function eventFunc:shortClick(item, ...)
    shortMgr:click(item, ...)
end

function eventFunc:emptyClick()
    shortMgr:emptyClick()
end

function eventFunc:enterEntityPosSetting()
    if self.enterEntityPosSettingFlag then
       self:leaveEntityPosSetting() 
    end
    self.enterEntityPosSettingFlag = true
    EditorModule:getMoveControl():enterOldEditorMoveWay()
    Lib.emitEvent(Event.EVENT_CHANGE_MAIN_UI_STATE, {isFly = true, isThirdView = false})
    bm:setPersonView(3)
end

function eventFunc:leaveEntityPosSetting()
    self.enterEntityPosSettingFlag = false
    EditorModule:getMoveControl():leaveOldEditorMoveWay()
    Lib.emitEvent(Event.EVENT_CHANGE_MAIN_UI_STATE, {
        isFly = EditorModule:getMoveControl():isEnableFly(),
        isThirdView = EditorModule:getMoveControl():isThirdView()
    })
end

function eventFunc:openBuildingTools()
    if self.openBuildingToolsFlag then
        self:closeBuildingTools() 
     end
    self.openBuildingToolsFlag = true
    EditorModule:getMoveControl():enterOldEditorMoveWay()
    Lib.emitEvent(Event.EVENT_CHANGE_MAIN_UI_STATE, {isFly = true, isThirdView = false})
    bm:setPersonView(3)
end

function eventFunc:closeBuildingTools()
    -- local pos = Blockman.instance:getCameraPos()
    -- Player.CurPlayer:setPosition(pos)
    EditorModule:getMoveControl():leaveOldEditorMoveWay()
    self.openBuildingToolsFlag = false
    Lib.emitEvent(Event.EVENT_CHANGE_MAIN_UI_STATE, {
        isFly = EditorModule:getMoveControl():isEnableFly(),
        isThirdView = EditorModule:getMoveControl():isThirdView()
    })
end

function eventFunc:enterGame()
    EditorModule:getMoveControl():switchFristMoveWay(true)
    Player.CurPlayer:setEditorModHideHp(false)
end

function eventFunc:changeMap()
    EditorModule:getMoveControl():enterOldEditorMoveWay()
    EditorModule:getMoveControl():leaveOldEditorMoveWay()
end

function eventFunc:BOUND_CHANGE(max, ...)
    EditorModule:getViewControl():setBoundSize(max, ...)
end

function eventFunc:enterEditorMode()
    Lib.emitEvent(Event.EVENT_STOP_DEAD_COUNTDOWN)
    Lib.emitEvent(Event.EVENT_CLOSE_ALL_WND)
    Lib.emitEvent(Event.EVENT_EDIT_MAP_MAKING)
    if self.deathEffectTimer then
        self.deathEffectTimer()
    end
    if self.deleteDeathEffect then
        self.deleteDeathEffect()
    end
    World.Timer(5, function()
            local gameRootPath = CGame.Instance():getGameRootDir()
            CGame.instance:restartGame(gameRootPath, World.GameName, 1, true)
            return false
    end)
end

function editorEventSolve:event(eventName, ...)
    local func = eventFunc[eventName]
    if func then
        func(eventFunc, ...)
    end
end

RETURN(editorEventSolve)

--- create_state.lua
---@type util
local util = require "common.util.util"
---@type engine_scene
local IScene = require "common.engine.engine_scene"
---@class CreateState : IGameManager
local CreateState = {}

function CreateState:enteredState(cfgId)
    --Lib.logDebug("CreateState:enteredState cfgId = ", cfgId)
    self.isCreated = false
    self.createModId = cfgId
    Lib.emitEvent(Event.EVENT_UNSELECT_TARGET)
    Lib.emitEvent(Event.EVENT_RESET_TARGET)
end

function CreateState:exitedState()
    --Lib.logDebug("CreateState:exitedState")
    self.createModId = nil
    self.isCreated = false
    Lib.emitEvent(Event.EVENT_RESET_GEOMETRY)
end

function CreateState:touchBegin(x, y)
    --Lib.logDebug("CreateState:touchBegin x and y = ", x, y)
    local result = IScene:raycast(Lib.v2(x, y), util:getRayLength(), 1 << 10, {})
    if result then
        local distance = (result.collidePos - Camera:getActiveCamera():getPosition()):len()
        if distance < util:getScreenSpaceCullDistance() then
            self.isCreated = true
            self:createMod(self.createModId, result.collidePos, Lib.v3(util:round(result.normalOnHitObject.x), util:round(result.normalOnHitObject.y), util:round(result.normalOnHitObject.z)))
        else
            Lib.emitEvent(Event.EVENT_SHOW_NOTIFICATION, Lang:toText("ui.create.out_of_range"))
        end
    end
end

function CreateState:touchMove(x, y)
    Lib.emitEvent(Event.EVENT_MOVE_TARGET, nil, Lib.v2(x, y))
end

function CreateState:touchEnd(x, y)
    if self.isCreated == true then
        self:popState("Create")
        Lib.emitEvent(Event.EVENT_SELECT_TARGET)
    end
end

return CreateState

print("client.editor_main loading")

local misc = require "misc"
---@type ConfigManager
local ConfigManager = T(MobileEditor, "ConfigManager")
---@type CommandManager
local CommandManager = T(MobileEditor, "CommandManager")
---@type GizmoManager
local GizmoManager = T(MobileEditor, "GizmoManager")
---@type MobileEditorCameraManager
local CameraManager = T(MobileEditor, "CameraManager")
---@type InputManager
local InputManager = T(MobileEditor, "InputManager")
---@type DataManager
local DataManager = T(MobileEditor, "DataManager")
---@type TargetManager
local TargetManager = T(MobileEditor, "TargetManager")
---@type SoundManager
local SoundManager = T(MobileEditor, "SoundManager")
---@type SkyboxManager
local SkyboxManager = T(MobileEditor, "SkyboxManager")
---@type LightManager
local LightManager = T(MobileEditor, "LightManager")
---@type WeatherManager
local WeatherManager = T(MobileEditor, "WeatherManager")
---@type GameManager
local GameManager = T(MobileEditor, "GameManager")
---@type UIManager
local UIManager = T(MobileEditor, "UIManager")

local main = {}
local events = {}

function main:init()
    Lib.setDebugLog(true)
    Lib.setLogLevel(1)
    World.CurWorld.enablePhysicsSimulation = false
    DrawRender.instance:setLineWidth(3)

    local gui = GUISystem.instance
    local lw, lh = gui:GetLogicWidth(), gui:GetLogicHeight()
    local sw, sh = gui:GetScreenWidth(), gui:GetScreenHeight()
    local rw, rh = Root.Instance():getRealWidth(), Root.Instance():getRealHeight()

    local deadZoneX = 6 / lw * sw
    local deadZoneY = 6 / lh * sh

    Blockman.Instance().gameSettings:setDeadZone(Lib.v2(deadZoneX, deadZoneY))

    ConfigManager:instance()
    CommandManager:instance()
    GizmoManager:instance()
    CameraManager:instance()
    DataManager:instance()
    TargetManager:instance()
    SoundManager:instance():load()
    SkyboxManager:instance():load()
    LightManager:instance()
    WeatherManager:instance()
    GameManager:instance()
    UIManager:instance():initMainUI()

    InputSystem.instance:addHandler(InputManager:instance(), 698)
    InputManager:instance().enabled = true
end

main:init()

--- c++ call lua
handle_input = function(frameTime)

end

local game_handle_tick = handle_tick
handle_tick = function(frameTime)
    game_handle_tick(frameTime)
    WeatherManager:instance():tick()
    GameManager:instance():tick()
    InputManager:instance():tick()
end

start_single = function ()
    Lib.logDebug("g2054 start_single isEditor = ", World.CurWorld.isEditor)
    local worldCfg = World.cfg
    local packet = {
        pid = "GameInfo",
        objID = 1,
        map = {
            id = 1,
            name = worldCfg.initPos.map or worldCfg.defaultMap or "map001",
            static = true
        },
        pos = worldCfg.initPos,
        isTimeStopped = false,
        worldTime = 1,
        maxPlayer = 1,
        skin = {},
    }
    handle_packet(misc.data_encode(packet))
end

gizmo_event_begin = function()
    GizmoManager:instance():handleEventBegin()
end

gizmo_event_move = function(...)
    GizmoManager:instance():handleEventMove(...)
end

gizmo_event_end = function()
    GizmoManager:instance():handleEventEnd()
end

client_event = function(event, ...)
    local handler = events[event]
    if not handler then
        print("no handler for client_event", event)
        return
    end
    handler(...)
end

--[[function events.changeCameraDistance(delta)
    Lib.logDebug("changeCameraDistance delta = ", delta)
    if delta ~= 0.0 then
        Lib.emitEvent(Event.EVENT_TOUCH_SCREEN_ZOOM, delta)
    end

end]]--

--[[window_event = function(event, window, ...)
    Lib.logDebug("mobile_editor window_event event = ", event)
    UIManager:instance():handleEvent(window, event, ...)
end]]--
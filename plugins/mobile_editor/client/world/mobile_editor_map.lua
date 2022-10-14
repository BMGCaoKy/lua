--- mobile_editor_map.lua
local Map = T(World, "Map")

local engine_loadCurMap = WorldClient.loadCurMap
function WorldClient:loadCurMap(data, pos, mapChunkData)
    Lib.logDebug("g2054 loadCurMap")
    engine_loadCurMap(self, data, pos, mapChunkData)

    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getOrCreateScene(World.CurWorld.CurMap.obj)
    manager:setCurScene(scene)
    Map.createScene(World.CurWorld.CurMap)

    ---@type MobileEditorCameraManager
    local CameraManager = T(MobileEditor, "CameraManager")
    CameraManager:instance():gotoState("ThirdPerson")

    ---@type GameManager
    local GameManager = T(MobileEditor, "GameManager")
    GameManager:instance():load()
    GameManager:instance():gotoState("Edit")

    ---@type WeatherManager
    local WeatherManager = T(MobileEditor, "WeatherManager")
    WeatherManager:instance():load()

    ---@type LightManager
    local LightManager = T(MobileEditor, "LightManager")
    LightManager:instance():load()

    ---@type GroundManager
    local GroundManager = T(MobileEditor, "GroundManager")
    GroundManager:instance():load()

end

local engine_init = Map.init
function Map:init(isCache)
    Lib.logDebug("g2054 map init")
    engine_init(self)

end



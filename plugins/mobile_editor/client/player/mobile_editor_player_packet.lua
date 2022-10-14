--- mobile_editor_player_packet.lua

print("mobile_editor player_packet")
local handles = T(Player, "PackageHandlers")

function handles:GameInfo(packet)
    Plugins.CallPluginFunc("onGameReady")
    local bm = Blockman.Instance()

    ---@type World
    local world = World.CurWorld
    world:setTimeStopped(packet.isTimeStopped)
    world:setWorldTime(packet.worldTime)
    world:loadCurMap(packet.map, packet.pos, packet.mapChunkData)
    bm:control().enable = true

    CGame.instance:setGetServerInfo(true);
    local worldCfg = World.cfg
    local WorldCameraCfg = worldCfg.cameraCfg

    if WorldCameraCfg then
        bm.gameSettings:loadCameraCfg(WorldCameraCfg)
    end

    if WorldCameraCfg then
        local pos = Lib.v3(worldCfg.initPos.x + worldCfg.cameraInitPosOffset.x, worldCfg.cameraInitPosOffset.y + 10, worldCfg.initPos.z + worldCfg.cameraInitPosOffset.z)
        Lib.emitEvent(Event.EVENT_SET_CAMERA, pos, 0, 15, 0) -- 45
    end

    World.CurWorld:setNeedShowLuaErrorMessage(packet.isShowErrorLog or false)
    CGame.instance:loadMapComplete()
end
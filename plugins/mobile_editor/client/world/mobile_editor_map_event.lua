--- mobile_editor_map_event.lua


local events = {}

function map_event(mapId, event, ...)
    -- client not need do anything
    --Lib.logDebug("g2054 map_event mapId and event = ", mapId, event)
    local func = events[event]
    if not func then
        print("no event!", event)
        return
    end

    local map = World.CurWorld:getMapById(mapId)
    if not map then
        Lib.logWarning("map_event map is nil ", event, ...)
    end
    Profiler:begin("map_event."..event)
    func(map, ...)
    Profiler:finish("map_event."..event)
end


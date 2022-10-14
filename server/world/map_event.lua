local events = {}
local curWorld = World.CurWorld

function events.mapBlockChange(map, pos, chunkPos, newId, oldId)
    MapPatchMgr.BlockChange(map, {pos = pos, newId = newId, oldId = oldId})
	map:blockChange(chunkPos, pos, newId)
end

function map_event(mapId, event, ...)
	local handler = events[event]
	if not handler then
		print("no handler for map_event", event)
		return
    end
    local map = World.CurWorld:getMapById(mapId)
    if not map then
        return
    end
	handler(map, ...)
end

function events.syncObject(map)
	map:syncSpawnEntity()
end
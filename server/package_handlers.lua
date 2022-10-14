local serverHandler = L("serverHandler", {})
local PackageHandlers = PackageHandlers

function PackageHandlers:Receive(name, func)
    serverHandler[name] = func
end

function PackageHandlers:SendToClient(player, name, packet)
    if not player or not player.isPlayer then
        return
    end
    player:sendPacket({
        pid = "ServerPackageHandler",
        name = name,
        package = packet
    })
end

function PackageHandlers:SendToAllClients(name, packet)
    WorldServer.BroadcastPacket({
        pid = "ServerPackageHandler",
        name = name,
        package = packet
    })
end

function PackageHandlers:SendToTrackingClients(entity, name, packet, includeSelf)
    if not entity then
        return
    end
    entity:sendPacketToTracking({
        pid = "ServerPackageHandler",
        name = name,
        package = packet
    }, includeSelf)
end

--------------Below is the old interface--------------

function PackageHandlers.registerServerHandler(name, func)
    PackageHandlers:Receive(name, func)
end

function PackageHandlers.receiveClientHandler(player, name, packet)
    local func = serverHandler[name]
    if not func then
        Lib.logWarning("no handler!", name)
        return
    end
    return func(player, packet)
end

function PackageHandlers.sendServerHandler(player, name, packet)
    PackageHandlers:SendToClient(player, name, packet)
end

function PackageHandlers.sendServerHandlerToTracking(entity, name, packet, includeSelf)
    PackageHandlers:SendToTrackingClients(entity, name, packet, includeSelf)
end

function PackageHandlers.sendServerHandlerToAll(name, packet)
    PackageHandlers:SendToAllClients(name, packet)
end
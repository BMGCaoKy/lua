local clientHandler = L("clientHandler", {})
local PackageHandlers = PackageHandlers

function PackageHandlers:Receive(name, func)
    clientHandler[name] = func
end

function PackageHandlers:SendToServer(name, packet, resp)
    if not Me then
        return
    end
    Me:sendPacket({
        pid = "ClientPackageHandler",
        name = name,
        package = packet
    }, resp)
end

--------------Below is the old interface--------------

function PackageHandlers.registerClientHandler(name, func)
    PackageHandlers:Receive(name, func)
end

function PackageHandlers.receiveServerHandler(player, name, packet)
    local func = clientHandler[name]
    if not func then
        Lib.logWarning("no handler!", name)
        return
    end
    Profiler:begin("receiveServerHandler."..name)
    local ok, err = pcall(func, player, packet)
    if not ok then
        print("PackageHandlers.receiveServerHandler error", name, err)
    end
    Profiler:finish("receiveServerHandler."..name)
end

function PackageHandlers.sendClientHandler(name, packet, resp)
    PackageHandlers:SendToServer(name, packet, resp)
end

function PackageHandlers.sendOtherClient(userId, name, packet)
    if not Me then
        return
    end
    Me:sendPacket({
        pid = "OtherClientHandler",
        name = name,
        userId = userId,
        package = packet
    })
end
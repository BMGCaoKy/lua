
--judge day or night at this time
function WorldServer.getCurTimeMode()
    local cfg = World.cfg
    local oneDayTime = assert(cfg.oneDayTime)
    local skyBox = assert(cfg.skyBox)
    local mod = skyBox.mod
    local skyCfg = assert(skyBox[mod])
    if skyCfg.stage then
        return skyCfg.stage
    end
    local time = World.CurWorld:getWorldTime()
    local hour = time % 24000 / 1000
    for i = #skyCfg, 1, -1 do
        local box = skyCfg[i]
        if hour >= box.time then
            return assert(box.stage)
        end
    end
    local box = skyCfg[#skyCfg]
    return assert(box.stage)
end
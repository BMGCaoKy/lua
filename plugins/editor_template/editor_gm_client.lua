require "common.gm"
local GMItem = GM:createGMItem()

GMItem["手机编辑器/除草神器"] = function(self)
    World.Timer(20, function()
        local player = Me
        local pos = player:getPosition()
        local min = Lib.v3(math.floor(pos.x - 50), math.floor(pos.y - 64), math.floor(pos.z - 50))
        local max = Lib.v3(math.floor(pos.x + 50), math.floor(pos.y + 10), math.floor(pos.z + 50))
        local map = World.CurMap
        min.y = min.y < 0 and 0 or min.y
        max.y = max.y > 255 and 255 or max.y
        local count = 0
        local result = map:getPosArrayWithIdsInArea(min, max, {31})
        local count = #result
        print("all grall count:", count, "to:", 250, "sub:", count - 250)
        for i = count, 250, -1 do
            local index = math.random(1, count)
            local pos = result[index]
            map:setBlockConfigId(pos, 0)
            table.remove(result, index)
            count = count -1
        end
        return true
    end)
end

return GMItem
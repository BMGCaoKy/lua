local SkillBase = Skill.GetType("Base")
local DropItem = Skill.GetType("DropItem")

function DropItem:cast(packet, from)
    local motion = Lib.tov3(packet.motion)
    local pos = packet.startPos
    local yaw
    local pitch
    if motion then
        yaw = math.deg(math.atan(motion.z, motion.x)) - 90
        local len = math.sqrt(motion.x ^ 2 + motion.z ^ 2)
        pitch = math.deg(math.atan(motion.y / len)) + 90
    end
    local item = Item.CreateItem(self.itemName, 1)
    if pos and item then
        local dropItem = DropItemServer.Create({
            map = from.map, pos = pos, item = item, lifeTime = self.vanishTime, pitch = pitch, yaw = yaw, 
            moveSpeed = self.moveSpeed, moveTime = self.moveTime, guardTime = self.guardTime
        })
        dropItem:setData("shake", self.shake or 0)
    end
end
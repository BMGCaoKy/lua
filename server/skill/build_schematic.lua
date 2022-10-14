
local setting = require "common.setting"
local SkillBase = Skill.GetType("Base")
local BuildSchematic = Skill.GetType("BuildSchematic")


function BuildSchematic:canCast(packet, from)
    --Lib.logDebug("engine BuildSchematic:canCast packet = ", Lib.v2s(packet, 7))
    if from and from.isPlayer and from:isWatch() then
        return false
    end

    if not packet.pos then
        return false
    end

    local map = from.map
    if map:getBlockConfigId(packet.pos) ~= Define.BlockId.AIR then
        return false
    end

    local slot = from:getHandItem()
    if not slot or slot:null() or not slot:cfg().itemType == "Schematic" then
        return false
    end


    return true

end

function BuildSchematic:cast(packet, from)
    --Lib.logDebug("BuildSchematic:cast packet = ", Lib.v2s(packet, 7))
    local map = from.map
    local slot = from:getHandItem()
    slot:consume()

    local schematic = from:getSchematic(packet.cfg.schematicFullName)
    local immediately = packet.immediately
    local configs = {}
    local halfWidth = math.floor(schematic:getWidth() / 2)
    local halfLength = math.floor(schematic:getLength() / 2)
    local yaw = packet.yaw % 360
    -- 旋转以后,initPos的世界坐标也跟着变换
    local initPos = nil
    if yaw == 0 then
        initPos = Lib.v3(packet.pos.x - halfWidth , packet.pos.y, packet.pos.z - halfLength )
    elseif yaw == 90 then
        initPos = Lib.v3(packet.pos.x + halfLength , packet.pos.y, packet.pos.z - halfWidth )
    elseif yaw == 180 then
        initPos = Lib.v3(packet.pos.x + halfWidth , packet.pos.y, packet.pos.z + halfLength )
    elseif yaw == 270 then
        initPos = Lib.v3(packet.pos.x - halfLength , packet.pos.y, packet.pos.z + halfWidth )
    end
    Lib.logDebug("initPos = ", Lib.v2s(initPos))

    for y = 0, schematic:getHeight() - 1 do
        for z = 0, schematic:getLength() - 1 do
            for x = 0, schematic:getWidth() - 1 do
                local pos = initPos + Quaternion.fromEulerAngle(0, -packet.yaw, 0) * Lib.v3(x, y, z)
                if map:getBlockConfigId(pos) == Define.BlockId.BUILD then
                    Lib.logDebug("found build block")
                    local key = nil
                    local building = nil
                    for k, v in pairs(map.buildings) do
                        if v.blockPos.x == pos.x and v.blockPos.y == pos.y and v.blockPos.z == pos.z then
                            key = k
                            building = v
                            break
                        end
                    end

                    if key and building then
                        local region = map:getRegion(key)
                        if region then
                            for _,entity in pairs(region.entities) do
                                if entity.isPlayer then
                                    entity:sendPacket({
                                        pid = "RemoveSchematicRegion",
                                        inRegionKey = key
                                    })
                                end
                            end

                            if region.schematicEntityObjID then
                                local schematicEntity = World.CurWorld:getEntity(region.schematicEntityObjID)
                                if schematicEntity then
                                    schematicEntity:destroy()
                                    region.schematicEntityObjID = nil
                                end
                            end
                            map:removeRegion(key)
                            map:setBuildingsData(key, nil)
                        end
                    end
                end

                if map:getBlockConfigId(pos) ~= Define.BlockId.BASE then
                    table.insert(configs, {
                        pos = pos,
                        id = Define.BlockId.AIR
                    })
                end
            end
        end
    end

    map:batchSetBlockConfigs(configs)

    -- 根据yaw转换initPos
    if immediately == false then
        local index = 1
        local block = schematic:getBlock(index)
        if block then
            local blockCfg = Block.GetNameCfg(setting:id2name("block", Define.BlockId.BUILD))
            Lib.logDebug("block.pos = ", block.pos)
            local startPos = initPos +  Quaternion.fromEulerAngle(0, -packet.yaw, 0) * block.pos
            Lib.logDebug("startPos = ", Lib.v2s(startPos))
            Block.onPlaceBlock(blockCfg, {
                ["name"] = "/place",
                ["fromID"] = from.objID,
                ["blockPos"] = startPos,
                ["isTouch"] = false,
                ["sideNormal"] = {
                    ["z"] = 0.0,
                    ["y"] = 0.0,
                    ["x"] = 0.0
                },
                ["fullName"] = packet.cfg.fullName,
                ["index"] = index,
                ["pos"] = packet.pos,
                ["count"] = schematic:getCount()
            }, from)
        end
    else
        for index = 1, Lib.getTableSize(schematic:getBlocks()) do
            local block = schematic:getBlock(index)
            if block then
                local pos = initPos + Quaternion.fromEulerAngle(0, -packet.yaw, 0) * block.pos
                if map:getBlockConfigId(pos) ~= Define.BlockId.BASE then
                    table.insert(configs, {
                        pos = pos,
                        id = block.id
                    })
                end
            end
        end

        from.map:batchSetBlockConfigs(configs)
    end

    SkillBase.cast(self, packet, from)
end
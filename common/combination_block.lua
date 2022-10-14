local PlaceFunc = L("PlaceFunc", {})

function PlaceFunc.door(cfg, basePos, map)
    local placef = cfg.placef
    local canMirrorList = placef.params
    for _, obj in pairs(canMirrorList) do
        local curPos = Lib.tov3(obj.pos) + basePos
        local cfg = map:getBlock(curPos)
        if cfg.fullName == obj.fullName then
            return Block.GetNameCfg(obj.mirrorBlockName)
        end
    end
    return cfg
end

function CombinationBlock:breakBlock(cfg, pos, map)
    local CombinationID = cfg.CombinationID 
    if not CombinationID then
        return false
    end
    local pos = Lib.tov3(pos)
    local placeCombination = cfg.placeCombination
    if not placeCombination then
        return false
    end
    local offset = Lib.tov3(placeCombination[CombinationID].pos)
    local basePos = pos - offset
    local placeInfo = {
        pos = basePos,
        cfg = map:getBlock(basePos)
    }
    for _, placeInfo in pairs(placeCombination) do
        local curPos = Lib.tov3(placeInfo.pos) + basePos
        map:setBlockConfigId(curPos, 0)
    end
    return true, placeInfo
end

function CombinationBlock:canPlace(cfg, pos, map)
    local placeCombination = cfg.placeCombination
    if placeCombination then
		for _, obj in pairs(placeCombination) do
			local offsetPos = Lib.tov3(obj.pos)
            local newPos = offsetPos + Lib.tov3(pos)
            print("map:getBlockConfigId(newPos)", map:getBlockConfigId(newPos), "=============")
            if map:getBlockConfigId(newPos) ~= 0 then
                return false
            end
		end
    end
    return true
end

function CombinationBlock:placeBlock(cfg, pos, map)
    -- todo
    pos = Lib.tov3(pos)
    local placef = cfg.placef
    if placef then
        cfg = PlaceFunc[placef.func](cfg, pos, map)
    end
    local placeCombination = cfg.placeCombination
	if placeCombination then
		for _, obj in pairs(placeCombination) do
			local offsetPos = Lib.tov3(obj.pos)
			local newPos = offsetPos + pos
			local combinationBlockID = Block.GetNameCfgId(obj.blockName)
			map:setBlockConfigId(newPos, combinationBlockID)
		end
        return true
    else
        return false
    end
end

function CombinationBlock:ClickChangeBlock(cfg, pos, map)
    local CombinationID = cfg.CombinationID 
    if not CombinationID then
        return
    end
    local pos = Lib.tov3(pos)
    local placeCombination = cfg.placeCombination
    if not placeCombination then
        return
    end
    local offset = Lib.tov3(placeCombination[CombinationID].pos)
    local basePos = pos - offset
    for _, placeInfo in pairs(placeCombination) do
        local curPos = Lib.tov3(placeInfo.pos) + basePos
        local cfg = map:getBlock(curPos)
        local clickChangeBlock = cfg.clickChangeBlock
        if clickChangeBlock then
            local toBlockCfg = Block.GetNameCfg(clickChangeBlock)
            map:setBlockConfigId(curPos, toBlockCfg.id)
        end
    end
end

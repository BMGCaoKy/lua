local savePoint = L("canRedoSet", {})
local entitys = {}

local function pos2Str(pos)
    return pos.x .. "," .. pos.y .. "," .. pos.z
end

function savePoint.canRedoSet(entity_obj, cfgName, args)
    local pos = args and args.pos
    if not pos then
        return true
    end
    local key = pos2Str(pos)
    if entitys[key] then
        return false
    end
    entitys[key] = true
    return true
end

RETURN(savePoint)

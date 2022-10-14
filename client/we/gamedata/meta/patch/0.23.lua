local Def = require "we.def"
local Lang = require "we.gamedata.lang"
local lfs = require "lfs"

local function check_union_children(obj)
    if obj.componentList and next(obj.componentList) then
        return
    end
    obj.componentList = {}
    local new_child = {}
    for _,child in ipairs(obj.children) do
        local cls = child.class
        if cls == "PartOperation" then
            check_union_children(child)
            table.insert(obj.componentList, child)
        elseif cls == "Part" then
            table.insert(obj.componentList, child)
        else
            table.insert(new_child, child)
        end
    end
    obj.children = new_child
end

local meta = {
    {
        type = "Instance_Spatial",
        value = function (oval)
            local nval = Lib.copy(oval)
            --OB默认使用动态合批
            nval.batchType = "Dynamic"
            return nval
        end
    },
    {
        type = "Instance_PartOperation",
        value = function (oval)
            local nval = Lib.copy(oval)
            check_union_children(nval)
            return nval
        end
    },
    {
        type = "GameCfg",
        value = function (oval)
            local nval = Lib.copy(oval)
            nval.partGameStaticBatch = true
            nval.meshPartStaticMergeRender = true
            nval.useHalfImageSize = true
            return nval
        end
    }
}

return {
	meta = meta
}
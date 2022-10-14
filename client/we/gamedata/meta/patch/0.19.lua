local Def = require "we.def"
local Lang = require "we.gamedata.lang"
local lfs = require "lfs"

local meta = {
	{
		type = "Instance_SceneUI",
		value = function(oval)
			local ret = Lib.copy(oval)

			ret.isFaceCamera = ret.isFaceCamra
			ret.size = ret.Size
			ret.rangeDistance = ret.RangeDistance
			ret.layoutFile = ret.LayoutFile
			ret.uiScaleMode = ret.UIScaleMode
			ret.stretch = ret.Stretch
	
			return ret
		end
	},

	{
        type = "Action_SetPartMaterialTexture",
        value = function(oval)
            local ret = Lib.copy(oval)
            local value_node = ret.components[1].params[2].value
            local action = value_node.action
            local rawval = value_node.rawval
            value_node = ctor("T_PartTexture")
            value_node.rawval = rawval
            value_node.action = action
            ret.components[1].params[2].value = value_node
            return ret
        end
	},

    {
        type = "Action_CreatePart",
        value = function(oval)
            local ret = Lib.copy(oval)
            local value_node = ret.components[1].params[5].value
            local action = value_node.action
            local rawval = value_node.rawval
            value_node = ctor("T_PartTexture")
            value_node.rawval = rawval
            value_node.action = action
            ret.components[1].params[5].value = value_node
            return ret
        end
	},

    {
        type = "Instance_PartOperation",
        value = function (oval)
            local ret = Lib.copy(oval)
            if not ret.btsKey or ret.btsKey == "" then
                local btsKey = GenUuid()
                ret.btsKey = btsKey
            end
            return ret
        end
    },

    {
        type = "Instance_MeshPart",
        value = function (oval)
            local ret = Lib.copy(oval)
            if not ret.btsKey or ret.btsKey == "" then
                local btsKey = GenUuid()
                ret.btsKey = btsKey
            end
            return ret
        end
    },

    {
        type = "Instance_EffectPart",
        value = function (oval)
            local ret = Lib.copy(oval)
            ret.scale = {x = 1, y = 1, z = 1}
            return ret
        end
    }
}

return {
	meta = meta
}
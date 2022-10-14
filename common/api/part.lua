local Utils = require "common.api.util"

local fieldMap = 
{
 Shape = {get = "getShape",set = "setShape"},
 Tiling = {get = "getTiling",set = "setTiling",  getTypeFunc = Utils.UV3ToVector2, setTypeFunc = Utils.Vector2ToUV3},
}

APIProxy.RegisterFieldMap(fieldMap)
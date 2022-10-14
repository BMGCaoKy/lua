local Utils = require "common.api.util"

local fieldMap = 
{
    Texture = {get = "getTexture", set = "setTexture"},
    Color = {get = "getColor", set = "setColor", getTypeFunc = Utils.ArrayToColor3, setTypeFunc = Utils.Color3ToArray},
    Transparency = {get = "getAlpha", set = "setAlpha"},
    FillType = {get = "getImageType", set = "setImageType"},
    Surface = {get = "getSurface", set = "setSurface"},
    TileOffset = {get = "getOffset", set = "setOffset", getTypeFunc = Utils.UV3ToVector2, setTypeFunc = Utils.Vector2ToUV3},
    Tiling = {get = "getTiling",set = "setTiling",  getTypeFunc = Utils.UV3ToVector2, setTypeFunc = Utils.Vector2ToUV3},
}

APIProxy.RegisterFieldMap(fieldMap)
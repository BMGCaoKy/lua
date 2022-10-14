local Utils = require "common.api.util"

local function slavePartToID(node)
    return node and node.id
end

local fieldMap =
{
    SlaveNode = {get = "getSlavePart", set = "setSlavePartID", setTypeFunc = slavePartToID},
    Enabled = {get = "isEnable", set = "setEnable"},
    Visible = {get = "isVisible", set = "setVisible"},
    Color = {get = "getColor", set = "setColor", getTypeFunc = Utils.ArrayToColor3, setTypeFunc = Utils.Color3ToArray},
}

APIProxy.RegisterFieldMap(fieldMap)
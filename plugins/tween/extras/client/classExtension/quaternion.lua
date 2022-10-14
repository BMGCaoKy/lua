function Quaternion.fromString(str)
    local keyArray = Lib.split(str, " ")
    local result = {}

    for _, v in ipairs(keyArray) do
        local singleKeyValue = Lib.split(v, ":")
        result[singleKeyValue[1]] = tonumber(singleKeyValue[2])  
    end

    return Quaternion.new(result.w, result.x, result.y, result.z)
end

---传入一个轴和需要旋转的弧度
---@param axis Vector3
---@param rad number
function Quaternion.fromRotation(axis, rad)
    local halfRotation = 0.5 * rad
    local halfSin = math.sin(halfRotation)
    return Quaternion.fromTable({w = math.cos(halfRotation), x = axis.x * halfSin, y = axis.y * halfSin, z = axis.z * halfSin}) 
end

function Quaternion:toString()
    return string.format("w:%s x:%s y:%s z:%s", self.w, self.x, self.y, self.z)
end


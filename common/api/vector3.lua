local vector3ProxyTb = {
    X = { get = function(t)
        return t.x
    end, set = function(t, v)
        t.x = v
    end },
    Y = { get = function(t)
        return t.y
    end, set = function(t, v)
        t.y = v
    end },
    Z = { get = function(t)
        return t.z
    end, set = function(t, v)
        t.z = v
    end },
    Normalized = { get = function(t)
        return t:normalize()
    end },
    Len = { get = function(t)
        return t:len()
    end },
    ctor = { get = function(t)
        return function(self, x, y, z)
            if classof(x) == "Vector3" then
                self.x = x.x
                self.y = x.y
                self.z = x.z
            else
                self.x = x or 0
                self.y = y or 0
                self.z = z or 0
            end
        end
    end }
}

local vector3StaticTb = {
    Zero = { get = function()
        return Vector3.new(0, 0, 0)
    end },
    One = { get = function()
        return Vector3.new(1, 1, 1)
    end },
    Forward = { get = function()
        return Vector3.new(0, 0, 1)
    end },
    Left = { get = function()
        return Vector3.new(1, 0, 0)
    end },
    Up = { get = function()
        return Vector3.new(0, 1, 0)
    end },
    Cross = { get = function()
        return function(v1, v2)
            return v1:cross(v2)
        end
    end },
    Dot = { get = function()
        return function(v1, v2)
            return v1:dot(v2)
        end
    end },
    LookRotation = { get = function()
        return function(v1, v2)
            local targetDir = v2 - v1
            local x, y, z = Quaternion.lookRotation(targetDir, Vector3.new(0, 0, 1)):toEulerAngle()
            return Vector3.new(x, y, z)
        end
    end },
    AngleBetween = { get = function()
        return function(v1, v2)
            return Vector3.angle(v1, v2)
        end
    end },
    Distance = { get = function()
        return function(v1, v2)
            local dx, dy, dz = v1.x - v2.x, v1.y - v2.y, v1.z - v2.z
            return math.sqrt(dx * dx + dy * dy + dz * dz)
        end
    end },
    ToLocalSpace = { get = function()
        return function(worldVec, movableNode)
            return movableNode:toLocalPosition(worldVec)
        end
    end },
    ToWorldSpace = { get = function()
        return function(localVec, movableNode)
            return movableNode:toWorldPosition(localVec)
        end
    end },
    Lerp = { get = function()
        return function(v1, v2, t)
            return Vector3.lerp(v1, v2, t)
        end
    end },
    MoveTowards = { get = function()
        return function(v1, v2, moveDistance)
            if moveDistance < 0 then
                assert(false, "moveDistance can't be negative!")
            end
            local targetDir = (v2 - v1).Normalized
            local xSmaller = v1.x < v2.x
            local ySmaller = v1.y < v2.y
            local zSmaller = v1.z < v2.z
            v1 = v1 + targetDir * moveDistance
            v1.x = xSmaller and math.min(v1.x, v2.x) or math.max(v1.x, v2.x)
            v1.y = ySmaller and math.min(v1.y, v2.y) or math.max(v1.y, v2.y)
            v1.z = zSmaller and math.min(v1.z, v2.z) or math.max(v1.z, v2.z)
            return v1
        end
    end },
}

APIProxy.OverrideAPI(Vector3, vector3ProxyTb, vector3StaticTb)
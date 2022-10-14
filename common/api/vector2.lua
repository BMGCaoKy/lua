local vector2ProxyTb = {
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
    Normalized = { get = function(t)
        return t:normalize()
    end },
    Len = { get = function(t)
        return t:len()
    end },
    ctor = { get = function(t)
        return function(self, x, y)
            if classof(x) == "Vector2" then
                self.x = x.x
                self.y = x.y
            else
                self.x = x or 0
                self.y = y or 0
            end
        end
    end }
}

local vector2StaticTb = {
    Zero = { get = function()
        return Vector2.new(0, 0)
    end },
    One = { get = function()
        return Vector2.new(1, 1)
    end },
    Left = { get = function()
        return Vector2.new(1, 0)
    end },
    Up = { get = function()
        return Vector2.new(0, 1)
    end },
    Dot = { get = function()
        return function(v1, v2)
            return v1:dot(v2)
        end
    end },
    AngleBetween = { get = function()
        return function(v1, v2)
            local t = (v1.x * v2.x + v1.y * v2.y) / (math.sqrt(math.pow(v1.x, 2) + math.pow(v1.y, 2)) * math.sqrt(math.pow(v2.x, 2) + math.pow(v2.y, 2)))
            local angle = math.deg(math.acos(t))
            return angle
        end
    end },
    Distance = { get = function()
        return function(v1, v2)
            local dx, dy = v1.x - v2.x, v1.y - v2.y
            return math.sqrt(dx * dx + dy * dy)
        end
    end },
    Lerp = { get = function()
        return function(v1, v2, t)
            return Vector2.lerp(v1, v2, t)
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
            v1 = v1 + targetDir * moveDistance
            v1.x = xSmaller and math.min(v1.x, v2.x) or math.max(v1.x, v2.x)
            v1.y = ySmaller and math.min(v1.y, v2.y) or math.max(v1.y, v2.y)
            return v1
        end
    end },
}

APIProxy.OverrideAPI(Vector2, vector2ProxyTb, vector2StaticTb)
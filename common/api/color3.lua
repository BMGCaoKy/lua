local color3ProxyTb = {
    R = { get = function(t)
        return t.r
    end, set = function(t, v)
        t.r = v
    end },
    G = { get = function(t)
        return t.g
    end, set = function(t, v)
        t.g = v
    end },
    B = { get = function(t)
        return t.b
    end, set = function(t, v)
        t.b = v
    end },
    ctor = { get = function(t)
        return function(self, r, g, b)
            if classof(r) == "Color3" then
                self.r = r.r
                self.g = r.g
                self.b = r.b
            else
                self.r = r or 0
                self.g = g or 0
                self.b = b or 0
            end
        end
    end }
}

local color3StaticTb = {
    White = { get = function()
        return Color3.new(1, 1, 1)
    end },
    Black = { get = function()
        return Color3.new(0, 0, 0)
    end },
    Red = { get = function()
        return Color3.new(1, 0, 0)
    end },
    Green = { get = function()
        return Color3.new(0, 1, 0)
    end },
    Blue = { get = function()
        return Color3.new(0, 0, 1)
    end },
    Yellow = { get = function()
        return Color3.new(1, 1, 0)
    end },
    Gray = { get = function()
        return Color3.new(119 / 255, 136 / 255, 153 / 255)
    end },
}

APIProxy.OverrideAPI(Color3, color3ProxyTb, color3StaticTb)
--由于引擎的Color3的RGB值不能设置为负数，没法参与缓动运算，
--所以需要写一个Color类来代替引擎的Color3类
--目标要求：接口和Color3一模一样，对外访问时只有正的RGB值，但是实际上存储的是带有负数的RGB值
rawset(_G, "Color", {})

local function LimitedRange(value, min, max)
    if value < min then
        return min
    elseif value > max then
        return max
    else
        return value
    end
end

local function calc(left, right, operator)
    if type(left) == "number" then
        local color = right.realColor
        return Color.new(operator(left, color.r), operator(left, color.g), operator(left, color.b), operator(left, color.a))
    elseif type(right) == "number" then
        local color = left.realColor
        return Color.new(operator(color.r, right), operator(color.g, right), operator(color.b, right), operator(color.a, right))
    else
        local color1 = left.realColor
        local color2 = right.realColor
        return Color.new(operator(color1.r, color2.r), operator(color1.g, color2.g), operator(color1.b, color2.b), operator(color1.a, color2.a))
    end
end

Color.r = nil
Color.g = nil
Color.b = nil
Color.a = nil

function Color.new(r, g, b, a)
    local instance = setmetatable({}, Color)

    instance.realColor = {
        r = r or 1,
        g = g or 1,
        b = b or 1,
        a = a or 1
    }

    return instance
end

function Color.fromRGBA(r, g, b, a)
    return Color.new(r / 255, g / 255, b / 255, a / 255)
end

function Color.fromHEX(hex)
    local _, _, A, R, G, B = string.find(hex, "^(%x%x)(%x%x)(%x%x)(%x%x)$")
    return Color.fromRGBA(tonumber(R, 16),tonumber(G, 16), tonumber(B, 16), tonumber(A, 16))
end

function Color.fromTable(t)
    return Color.new(t.r, t.g, t.b, t.a)
end

function Color:toRGBA()
    return {
        r = self.r * 255,
        g = self.g * 255,
        b = self.b * 255,
        a = self.a * 255
    }
end

function Color:toHEX()
    return string.format(
        "%02X%02X%02X%02X", 
        math.ceil(self.a * 255), 
        math.ceil(self.r * 255), 
        math.ceil(self.g * 255), 
        math.ceil(self.b * 255)
    )
end

function Color:toRGBAString()
    return string.format("R:%0.2f, G:%0.2f, B:%0.2f, A:%0.2f", self.r, self.g, self.b, self.a)
end

function Color.__index(self, key)
    local realColor = rawget(self, "realColor")

    if realColor and realColor[key] then
        return LimitedRange(self.realColor[key], 0, 1)
    else
        return rawget(self, key) or Color[key]
    end 
end

function Color.__newindex(self, key, value)
    if self.realColor and self.realColor[key] then
        self.realColor[key] = value
    else
        rawset(self, key, value)
    end
end

function Color.__tostring(self)
    return self:toHEX()
end

function Color.__add(left, right)
    return calc(left, right, function(l, r) 
        return l + r 
    end)
end

function Color.__sub(left, right)
    return calc(left, right, function(l, r) 
        return l - r 
    end)
end

function Color.__mul(left, right)
    return calc(left, right, function(l, r) 
        return l * r 
    end)
end

function Color.__div(left, right)
    return calc(left, right, function(l, r) 
        return l / r 
    end)
end

function Color.__unm(self)
    return Color.__mul(self, -1)
end

Color.white = Color.new(1, 1, 1)
Color.black = Color.new(0, 0, 0)
Color.red   = Color.new(1, 0, 0)
Color.green = Color.new(0, 1, 0)
Color.blue  = Color.new(0, 0, 1)
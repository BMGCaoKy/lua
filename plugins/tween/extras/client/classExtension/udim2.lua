function UDim2.__mul(left, right)
    if type(left) == "number" then
        return UDim2.new(left * right[1], left * right[2])
    elseif type(right) ==  "number" then
        return UDim2.new(left[1] * right, left[2] * right)
    else
        return UDim2.new(left[1] * right[1], left[2] * right[2])
    end
end

function UDim2.__div(left, right)
    if type(left) == "number" then
        return UDim2.new(left / right[1], left / right[2])
    elseif type(right) ==  "number" then
        return UDim2.new(left[1] / right, left[2] / right)
    else
        return UDim2.new(left[1] / right[1], left[2] / right[2])
    end
end

function UDim2.__tostring(self)
    return string.format("{%s,%s}", tostring(self[1]), tostring(self[2])) 
end
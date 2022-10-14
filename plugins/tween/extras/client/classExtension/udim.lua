function UDim.__mul(left, right)
    if type(left) == "number" then
        return UDim.new(left * right.scale, left * right.offset)
    elseif type(right) == "number" then
        return UDim.new(left.scale * right, left.offset * right)
    else
        return UDim.new(left.scale * right.scale, left.offset * right.offset)
    end
end

function UDim.__div(left, right)
    if type(left) == "number" then
        return UDim.new(left / right.scale, left / right.offset)
    elseif type(right) == "number" then
        return UDim.new(left.scale / right, left.offset / right)
    else
        return UDim.new(left.scale / right.scale, left.offset / right.offset)
    end
end

function UDim.__tostring(self)
    return string.format("{%s,%s}", tostring(self.scale), tostring(self.offset))
end
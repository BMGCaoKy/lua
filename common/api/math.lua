function math.lerp(v1, v2, t)
    return (v2 - v1) * t + v1
end

function math.inverseLerp(min, max, value)
    value = math.max(value, min)
    value = math.min(value, max)
    assert(max - min > 0, string.format("max must bigger than min!"))
    return (value - min) / (max - min)
end

function math.moveTowards(v1, v2, moveDistance)
    if moveDistance < 0 then
        assert(false, "moveDistance can't be negative!")
    end
    local vSmaller = v1 < v2
    v1 = v1 + moveDistance
    v1 = vSmaller and math.min(v1, v2) or math.max(v1, v2)
    return v1
end

function math.clamp(val, minVal, maxVal)
    local ret = val
    ret = math.max(ret, minVal)
    ret = math.min(ret, maxVal)
    return ret
end
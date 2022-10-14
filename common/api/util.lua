local Utils = {}

function Utils.Vector2ToUV3(v2)
    return Vector3.new(v2.x, v2.y, 1)
end

function Utils.UV3ToVector2(v3)
    return Vector2.new(v3.x, v3.y)
end

function Utils.Color3ToArray(color)
    return {color.r, color.g, color.b}
end

function Utils.ArrayToColor3(v3)
    return Color3.new(v3[1], v3[2], v3[3])
end

function Utils.ToNewVector3(v3)
    return Vector3.new(v3.x, v3.y, v3.z)
end

function Utils.ToNewVector2(v2)
    return Vector2.new(v2.x, v2.y)
end

function Utils.CheckLayoutSuffix(layoutName)
	local suffix = ".layout"
    if not string.find(layoutName, suffix) then
       layoutName = layoutName .. suffix
    end
	return layoutName
end

return Utils
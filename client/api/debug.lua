local debugDraw = DebugDraw.instance

local function checkDebugDraw()
    if not debugDraw:isEnabled() then
		debugDraw:setEnabled(true)
	end
    debugDraw:setLineWidth(2.5)
end

local function uInt32FromRGBA(color)
    local r = color.r or 1
    local g = color.g or 1
    local b = color.b or 1
    local a = color.a or 1
    r = math.ceil(r * 255)
    g = math.ceil(g * 255)
    b = math.ceil(b * 255)
    a = math.ceil(a * 255)
    local ret = (r << 24) | (g << 16) | (b << 8) | a
    return ret
end

local function frameToMs(frameCount)
    return frameCount / 20 * 1000
end

function Debug:DrawLine(startPos, endPos, color, frameCount)
    checkDebugDraw()
    color = color or Color3.White
    local duration = frameToMs(frameCount or 20)
    debugDraw:addLine(startPos, endPos, uInt32FromRGBA(color), duration)
end

function Debug:DrawBox(center, extend, direction, color, frameCount)
    checkDebugDraw()
    direction = direction or Lib.v3(0, 0, 0)
    color = color or Color3.White
    local duration = frameToMs(frameCount or 20)
    debugDraw:addBox(center, extend / 2, direction, uInt32FromRGBA(color), duration)
end

function Debug:DrawSphere(center, radius, color, frameCount)
    checkDebugDraw()
    color = color or Color3.White
    local duration = frameToMs(frameCount or 20)
    debugDraw:addSphere(center, radius, uInt32FromRGBA(color), duration)
end

function Debug:ClearDraw()
    checkDebugDraw()
    debugDraw:clearDebugObjects()
end

function Debug:SetDrawColliderEnabled(enabled)
    checkDebugDraw()
    debugDraw:setDrawColliderEnabled(enabled)
end
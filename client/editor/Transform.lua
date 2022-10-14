local Transform = {}

local Direction = {
    NONE = 0, UP = 1, DOWN = 2, LEFT = 3, RIGHT = 4, FRONT = 5, BACK = 6
}

-- 计算两点的位置关系
local function CalcPositionRelations(offsetPos)
    if offsetPos.x ~= 0 then
        return offsetPos.x > 0 and Direction.LEFT or Direction.RIGHT
    end
    if offsetPos.y ~= 0 then
        return offsetPos.y > 0 and Direction.DOWN or Direction.UP
    end
    if offsetPos.z ~= 0 then
        return offsetPos.z > 0 and Direction.BACK or Direction.FRONT
    end
    return Direction.NONE
end

-- 最小点  长宽高  接触面的偏移值     中间对齐
function Transform.CenterAlign(min_pos, size, offsetPos)
    local box_x, box_y, box_z = size.lx, size.ly, size.lz
    if box_x == 1 and box_y == 1 and box_z == 1 then
        return min_pos
    end
    local dir = CalcPositionRelations(offsetPos)
    local minPosition = {}
    minPosition.x = min_pos.x
    minPosition.y = min_pos.y
    minPosition.z = min_pos.z
    if dir == Direction.UP or dir == Direction.DOWN then
        --  移动  x 和  z
        minPosition.x = min_pos.x - (box_x == 2 and 0 or math.floor(box_x / 2))
        minPosition.z = min_pos.z - (box_z == 2 and 0 or math.floor(box_z / 2))
        if dir == Direction.UP then
            minPosition.y = minPosition.y - box_y + 1
        end
    elseif dir == Direction.LEFT or dir == Direction.RIGHT then
        --  移动  z 和  y
        minPosition.y = min_pos.y - (box_y == 2 and 0 or math.floor(box_y / 2))
        minPosition.z = min_pos.z - (box_z == 2 and 0 or math.floor(box_z / 2))
        if dir == Direction.RIGHT then
            minPosition.x = minPosition.x - box_x + 1
        end
    elseif dir == Direction.FRONT or dir == Direction.BACK then
        --移动 x  y
        minPosition.x = min_pos.x - (box_x == 2 and 0 or math.floor(box_x / 2))
        minPosition.y = min_pos.y - (box_y == 2 and 0 or math.floor(box_y / 2))
        if dir == Direction.FRONT then
            minPosition.z = minPosition.z - box_z + 1
        end
    end
    return minPosition
end

return Transform
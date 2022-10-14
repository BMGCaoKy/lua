function UI:getArea2(wnd)
    local curPos = wnd:getPosition()
    local curSize = wnd:getSize()

    return{
        [1] = curPos[1],
        [2] = curPos[2],
        [3] = curSize.width,
        [4] = curSize.height,
    }
end
local renderHandler = {}
local index = 0

do
    local function doUpdate()
        for id, handler in pairs(renderHandler) do
            local result = handler()

            if not result then
                renderHandler[id] = nil
            end
        end
    end

    if World.isClient then
        DrawRender.addEntry("easing", function()
            doUpdate()
        end)
        DrawRender:setEasingEnabled(true)
    else
        World.Timer(1, function()
            doUpdate()
            return true
        end)
    end
end

local function register(func)
    index = index + 1
    local curIndex = index

    renderHandler[curIndex] = func

    return function()
        renderHandler[curIndex] = nil
    end
end

return register
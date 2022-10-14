local TouchScreenHandler = class('TouchScreenHandler')
function TouchScreenHandler:ctor()
    self.touches = {}
end

function TouchScreenHandler:handleInput(input)
    if input.type ~= InputType.TouchScreen then
        return false
    end

    local SUBTYPE = TouchScreenInputSubType
    local subtype = input.subtype

    if subtype == SUBTYPE.TouchDown then
        for _, touch in ipairs(input.touches) do
            self.touches[touch.id] = {
                current = touch.position,
                prev = touch.position,
            }
        end
    elseif subtype == SUBTYPE.TouchUp or subtype == SUBTYPE.TouchCancel then
        for _, touch in ipairs(input.touches) do
            self.touches[touch.id] = nil
        end
    elseif subtype == SUBTYPE.TouchMove then
        for _, touch in ipairs(input.touches) do
            local old = self.touches[touch.id]
            if old then
                self.touches[touch.id] = {
                    current = touch.position,
                    prev = old.current,
                }
            end
        end

        if self:checkZoom() then
            return true
        end
    end

    return false
end

function TouchScreenHandler:checkZoom()
    if Lib.getTableSize(self.touches) ~= 2 then
        return false
    end

    local ids = {}
    for id in pairs(self.touches) do
        table.insert(ids, id)
    end

    local id1, id2 = table.unpack(ids)
    local currentLen = (self.touches[id2].current - self.touches[id1].current):len()
    local prevLen = (self.touches[id2].prev - self.touches[id1].prev):len()
    Lib.emitEvent(Event.EVENT_TOUCH_SCREEN_ZOOM, currentLen - prevLen)
    return true
end
 
local handler = TouchScreenHandler.new()
InputSystem.instance:addHandler(handler, 699)


local misc = require "misc"
local now_nanoseconds = misc.now_nanoseconds
local function getTime()
    return now_nanoseconds() / 1000000
end


function M:init()
    local begin1
    begin1 = getTime()
    WinBase.init(self, "Chat.json", true)
    begin1 = getTime()
end

function M:onOpen()
    UI:closeWnd(self)
end

function M:onClose()

end

return M
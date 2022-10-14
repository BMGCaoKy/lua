
---@class StoryWriter
local LuaTimer = T(Lib, "LuaTimer") ---@type LuaTimer

local StoryWriter = Lib.class("StoryWriter")

function StoryWriter:ctor()
    self.duration = 25
    self.index = 1
    self.text = ""
end


function StoryWriter:write(text, onWrite, onFinish)
    --Lib.logInfo("StoryWriter:write text = ", text)
    local length = Lib.subStringGetTotalIndex(text)
    --Lib.logInfo("StoryWriter:write length = ", length)
    local index = 1
    self.timer = LuaTimer:scheduleTimer(function()
        --Lib.logInfo("write self.index = ", self.index)
        local content = Lib.subStringUTF8(text, 1, self.index)
        --Lib.logInfo("content = ", content)
        onWrite(self.text .. content)

        self.index = self.index + 1
        index = index + 1
        --Lib.logInfo("index = ", index)
        if index > length then

            LuaTimer:cancel(self.timer)
            self.timer = nil
            self.text = self.text .. text
            --Lib.logInfo("finish StoryWriter:write self.text = ", self.text)
            onFinish()
        end
    end, self.duration, length)
end

function StoryWriter:reset()
    self.text = ""
    self.index = 1
end


return StoryWriter
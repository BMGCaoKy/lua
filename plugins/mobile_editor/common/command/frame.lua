--- frame.lua
--- 帧
local class = require "common.3rd.middleclass.middleclass"
---@class Frame : middleclass
local Frame = class('Frame')

function Frame:initialize()
    self.commands = {}
end

function Frame:hasCommands()
    return Lib.getTableSize(self.commands) > 0
end

function Frame:execute()
    Lib.logDebug("Frame:execute")
    for i = 1, #self.commands do
        local command = self.commands[i]
        if command then
            Lib.logDebug("command:execute")
            command:execute()
        end
    end
end


function Frame:push(command)
    table.insert(self.commands, command)
end

function Frame:update(params)
    --Lib.logDebug("Frame:update")
    local command = self.commands[#self.commands]
    if command then
        --Lib.logDebug("command:update")
        command:update(params)
    end
end

function Frame:undo()
    --Lib.logDebug("Frame:undo")
    for i = #self.commands, 1, -1 do
        local command = self.commands[i]
        if command then
            command:undo()
        end
    end

end

function Frame:redo()
    --Lib.logDebug("Frame:redo")
    for i = 1, #self.commands do
        local command = self.commands[i]
        if command then
            --Lib.logDebug("command:redo")
            command:redo()
        end
    end
end


return Frame
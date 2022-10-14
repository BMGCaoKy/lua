--- command.lua
--- 命令基类
local class = require "common.3rd.middleclass.middleclass"
---@class Command : middleclass
local Command = class('Command')

function Command:initialize(targets)
    if targets then
        self.targets = Lib.copyTable1(targets)
    end
end

function Command:execute()

end

function Command:update(params)

end

function Command:undo()

end

function Command:redo()

end


return Command
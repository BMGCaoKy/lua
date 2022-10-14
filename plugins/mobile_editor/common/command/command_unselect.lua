--- command_unselect.lua

local class = require "common.3rd.middleclass.middleclass"
---@type Command
local Command = require "common.command.command"
---@class CommandUnSelect : Command
local CommandUnSelect = class("CommandUnSelect", Command)

function CommandUnSelect:initialize(targets)
    Command.initialize(self, targets)

end

function CommandUnSelect:execute()

end

function CommandUnSelect:undo()

end

function CommandUnSelect:redo()

end



return CommandUnSelect
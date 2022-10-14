--- command_select.lua

local class = require "common.3rd.middleclass.middleclass"
---@type Command
local Command = require "common.command.command"
---@class CommandSelect : Command
local CommandSelect = class("CommandSelect", Command)

function CommandSelect:initialize(targets)
    Command.initialize(self, targets)

end

function CommandSelect:execute()

end

function CommandSelect:undo()

end

function CommandSelect:redo()

end



return CommandSelect
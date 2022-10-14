--- command_manager.lua
--- 命令的管理器
--- 命令系统模拟C/C++函数的callstack 包含多个frame(栈帧),每个frame中包含多个command
--- command是原子的执行单元 frame是多个command的集合
---@class CommandManager : singleton
local CommandManager = T(MobileEditor, "CommandManager")

---@type Frame
local Frame = require "common.command.frame"

function CommandManager:initialize()
    ---@type Frame[]
    self.stack = {}
    self.limit = 1024
    self.current = 0
    self.activeFrame = false
    self:subscribeEvents()
end

function CommandManager:finalize()

end

function CommandManager:startFrame()
    self.activeFrame = true
    for i = #self.stack, self.current + 1, -1 do
        self.stack[i] = nil
    end
    local frame = Frame:new()
    table.insert(self.stack, frame)
    if #self.stack >= self.limit then
        table.remove(self.stack, 1)
    else
        self.current = self.current + 1
    end
end

function CommandManager:endFrame()
    local frame = self.stack[self.current]
    if frame then
        if frame:hasCommands() then
            self.activeFrame = false
        else
            self:resetFrame()
        end
    end
end

function CommandManager:resetFrame()
    self.activeFrame = false
    self:undo()
    self.stack[self.current + 1] = nil
    Lib.emitEvent(Event.EVENT_CHECK_UNDO_REDO)
end

function CommandManager:subscribeEvents()
    Lib.subscribeEvent(Event.EVENT_UNDO_COMMAND, function()
        self:undo()
    end)

    Lib.subscribeEvent(Event.EVENT_REDO_COMMAND, function()
        self:redo()
    end)

    Lib.subscribeEvent(Event.EVENT_UPDATE_COMMAND, function(params)
        self:update(params)
    end)
end

---@param command Command
function CommandManager:register(command)
    if self.activeFrame == true then
        local frame = self.stack[self.current]
        if frame then
            frame:push(command)
            command:execute()
        end
    else
        for i = #self.stack, self.current + 1, -1 do
            self.stack[i] = nil
        end
        local frame = Frame:new()
        frame:push(command)
        table.insert(self.stack, frame)
        command:execute()
        if #self.stack >= self.limit then
            table.remove(self.stack, 1)
        else
            self.current = self.current + 1
        end
        Lib.emitEvent(Event.EVENT_CHECK_UNDO_REDO)
    end
end

function CommandManager:update(params)
    if self.current <= 0 then
        return
    end

    local frame = self.stack[self.current]
    if frame then
        frame:update(params)
    end
end

function CommandManager:undo()
    if self.current <= 0 then
        return
    end

    local frame = self.stack[self.current]
    if frame then
        frame:undo()
        self.current = self.current - 1
        Lib.emitEvent(Event.EVENT_CHECK_UNDO_REDO)
    end
end

function CommandManager:redo()
    if self.current >= #self.stack then
        return
    end

    local frame = self.stack[self.current + 1]
    if frame then
        frame:redo()
        self.current = self.current + 1
        Lib.emitEvent(Event.EVENT_CHECK_UNDO_REDO)
    end
end

function CommandManager:checkRedo()
    if self.current >= 0 and self.current < #self.stack then
        return true
    end

    return false
end

function CommandManager:checkUndo()
    if self.current > 0 and self.current <= #self.stack then
        return true
    end

    return false
end

function CommandManager:reset()
    self.stack = {}
    self.current = 0
    self.activeFrame = false
end

return CommandManager
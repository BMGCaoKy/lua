--- touch.lua
--- 触摸数据结构
local class = require "common.3rd.middleclass.middleclass"
---@class Touch : middleclass
local Touch = class('Touch')

function Touch:initialize(id, prevPos)
    self.id = id
    self.prevPos = prevPos
    self.curPos = self.prevPos
end

function Touch:getId()
    return self.id
end

function Touch:getPrevPos()
    return self.prevPos
end

function Touch:setPrevPos(pos)
    self.prevPos = pos
end

function Touch:getCurPos()
    return self.curPos
end

function Touch:setCurPos(pos)
    self.curPos = pos
end

return Touch
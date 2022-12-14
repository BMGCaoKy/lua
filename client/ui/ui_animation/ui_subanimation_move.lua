---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by wangpq.
--- DateTime: 2020/5/27 20:20
---
---@class UISubAnimationTextScaleMove : UISubAnimation
local UISubAnimationTextScaleMove = Lib.class("UISubAnimationTextScaleMove", require "ui.ui_animation.ui_subAnimation")

function UISubAnimationTextScaleMove:onPlay()
    self.moveStart = Lib.strToV4(self.param and self.param.moveStart or self.config.moveStart)
    self.moveEnd = Lib.strToV4(self.param and self.param.moveEnd or self.config.moveEnd)
    self.move = self.moveStart
    self.moveDelta = (self.moveEnd - self.moveStart) / self.ticks
end

function UISubAnimationTextScaleMove:onUpdate()
    if self.tick == self.ticks then
        self.move = self.moveEnd
    else
        self.move = self.move + self.moveDelta
    end

    self.window:SetXPosition({ self.move.x, self.move.y })
    self.window:SetYPosition({ self.move.z, self.move.w })

    --Lib.logDebug("UISubAnimationTextScaleMove:onUpdate ", self.move.x, self.move.y, self.move.z, self.move.w)
end

function UISubAnimationTextScaleMove:onDestroy()
    --TODO
end

return UISubAnimationTextScaleMove
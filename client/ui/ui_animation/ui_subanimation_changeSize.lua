---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by wangpq.
--- DateTime: 2020/5/27 18:02
---
---@class UISubAnimationChangeSize : UISubAnimation
local UISubAnimationChangeSize = Lib.class("UISubAnimationChangeSize", require "ui.ui_animation.ui_subAnimation")

function UISubAnimationChangeSize:onPlay()
    self.sizeStart = Lib.strToV4(self.param and self.param.sizeStart or self.config.sizeStart)
    self.sizeEnd = Lib.strToV4(self.param and self.param.sizeEnd or self.config.sizeEnd)
    self.size = self.sizeStart
    self.sizeDelta = (self.sizeEnd - self.sizeStart) / self.ticks
end

function UISubAnimationChangeSize:onUpdate()
    if self.tick == self.ticks then
        self.size = self.sizeEnd
    else
        self.size = self.size + self.sizeDelta
    end
    self.window:SetWidth({self.size.x, self.size.y})
    self.window:SetHeight({self.size.z, self.size.w})
end

function UISubAnimationChangeSize:onDestroy()
    --TODO
end

return UISubAnimationChangeSize
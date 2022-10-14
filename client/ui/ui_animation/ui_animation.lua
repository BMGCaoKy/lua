---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by bell.
--- DateTime: 2020/4/13 17:33
---
---@class UIAnimation
local UIAnimation = Lib.class("UIAnimation")

local animationMap = {
    ["TextColor"] = require "ui.ui_animation.ui_subAnimation_textColor",
    ["alpha"] = require "ui.ui_animation.ui_subAnimation_alpha",
    ["scale"] = require "ui.ui_animation.ui_subanimation_scale",
    ["ScaleXYZ"] = require "ui.ui_animation.ui_subanimation_scaleXYZ",
    ["move"] = require "ui.ui_animation.ui_subanimation_move",
    ["ChangeSize"] = require "ui.ui_animation.ui_subanimation_changeSize",
    ["BackgroundColor"] = require "ui.ui_animation.ui_subanimation_backgroundColor",
    ["mask"] = require "ui.ui_animation.ui_subAnimation_mask",
}

function UIAnimation:ctor(window, config, callBack, uid, params)
    self.window = window
    self.config = config
    self.callBack = callBack
    self.uid = uid
    self.params = params
    self.isEnd = false

    self.time = tonumber(self.config.time) or 0
    self.startTime = os.time()

    self.sync = Lib.toBool(self.config.sync)
    self.loop = Lib.toBool(self.config.loop)

    self:parseUISubAnimation()
end

function UIAnimation:parseUISubAnimation()
    self.subAnimations = {}
    for i = 1, #self.config.childs do
        local child = self.config.childs[i]
        local param = self.params and self.params[i] or nil
        local class = animationMap[child.animType]
        if class then
            local subAnimation = class.new(self.window, child, param)
            table.insert(self.subAnimations, subAnimation)
        else
            Lib.log("UIAnimation:parseUISubAnimation not class " .. child.animType, 4)
        end
    end
end

function UIAnimation:play(continue)
    self.isEnd = false

    if not continue then
        self.startTime = os.time()
    end

    for _, subAnimation in pairs(self.subAnimations) do
        subAnimation:play()
    end
end

function UIAnimation:update()
    if self.isEnd then
        return
    end

    if self.sync then
        self:updateSync()
    else
        self:updateNoSync()
    end

    if self.loop and self.isEnd
            and os.time() - self.startTime < self.time / 1000 then
        self:parseUISubAnimation()
        self:play(true)
    end
end

function UIAnimation:destroy()
    if self.callBack then
        self:callBack()
    end
end

function UIAnimation:updateSync()
    self.isEnd = true
    for _, subAnimation in pairs(self.subAnimations) do
        subAnimation:update()
        if not subAnimation.isEnd then
            self.isEnd = false
        end
    end
end

function UIAnimation:destroyByManual()
    if self.subAnimations[1] then
        self.subAnimations[1]:destroy()
    end
end

function UIAnimation:updateNoSync()
    self.isEnd = false
    if #self.subAnimations == 0 then
        self.isEnd = true
    else
        self.subAnimations[1]:update()

        if self.subAnimations[1].isEnd then
            table.remove(self.subAnimations, 1)
        end
    end
end

return UIAnimation
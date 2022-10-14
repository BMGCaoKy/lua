local extends = require "core.tools".extends
local super = require "core.base.params"
local XPCall = require "core.tools".XPCallByPackArgs
local easing = require "core.easing"

local params = extends(super) ---@class TweenerParams : TweenBaseParams

params.from = nil
params.to = nil
params.duration = nil

params.ease = easing.outExpo

function params:init(to, duration)
    self.to = to
    self.duration = duration
end

return function()
    return setmetatable({},{__index = params})
end
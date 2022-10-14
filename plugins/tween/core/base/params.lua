local params = {} ---@class TweenBaseParams

local enum = require "core.enum"
local XPCall = require "core.tools".XPCallByPackArgs

params.autoKill = true
params.delayTime = 0
params.loopCount = 1
params.loopType = enum.loopType.Yoyo
params.timeScale = 1

params.onStart = nil
params.onStartArgs = nil
params.onFinish = nil
params.onFinishArgs = nil
params.onUpdate = nil
params.onUpdateArgs = nil
params.onStepCompleted = nil
params.onStepCompletedArgs = nil

function params:start()
    XPCall(self.onStart, self.onStartArgs)
end

function params:finish()
    XPCall(self.onFinish, self.onFinishArgs)
end

function params:update()
    XPCall(self.onUpdate, self.onUpdateArgs)
end

function params:stepCompleted()
    XPCall(self.onStepCompleted, self.onStepCompletedArgs)
end

return params
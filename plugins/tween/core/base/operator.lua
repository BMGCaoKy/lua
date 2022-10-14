local manager = require "core.manager"
local enum = require "core.enum"

local operator = {} ---@class TweenBaseOperator

operator._tweenBase = nil ---@type TweenBase
operator._tid = nil
operator._isValid = nil
operator.isTweenOperator = true

---@param tweenBase TweenBase
function operator:init(tweenBase, tid)
    self._tweenBase = tweenBase
    self._tid = tid
    self._isValid = true ---@private
    self._verifyHandler = nil
end

---缓动唯一标识 ID
---@return any
function operator:tid()
    return self._tid
end

---本实例是否还有效
---@return boolean
function operator:isValid()
    if type(self._verifyHandler) == "function" then
        return self._verifyHandler and self._verifyHandler()
    end
    return self._isValid
end

function operator:setVerifyHandler(handler)
    self._verifyHandler = handler
end

---缓动结束后是否自动销毁
---@param value boolean
function operator:setAutoKill(value)
    self._tweenBase.params.autoKill = value
    return self
end

---设置循环
---@param count number 循环次数
---@param loopType LoopType 循环类型
---@overload fun(count : number) : TweenBase
function operator:setLoops(count, loopType)
    if loopType and not enum.loopType[loopType] then
        print(string.format("循环类型[ %s ]不存在", tostring(loopType)))
    end
    
    self._tweenBase.params.loopCount = count
    self._tweenBase.params.loopType = loopType or LoopType.Yoyo

    return self
end

---设置时间流逝速度
---@param value number
function operator:setTimeScale(value)
    -- 注释原因：也可以由timeScale来决定动画是否逆播放
    --if value < 0 then
    --    pcall(error("Time scale 的值不能为负数!"))
    --    return self
    --end

    self._tweenBase.params.timeScale = value
    return self
end

---设置本次缓动延时启动
---@param value number 延时的时间，秒为单位
function operator:delay(value)
    self._tweenBase.params.delayTime = value
    self._tweenBase.status:setDelay(value)
    return self
end

---暂停缓动
function operator:pause()
    self._tweenBase.status:setPause(true)
end

---继续缓动，与暂停对应
function operator:continue()
    self._tweenBase.status:setPause(false)
end

---重新开始，对于一些数据不重置：例如：已播放次数
function operator:restart()
    self._tweenBase:restart()
end

---重置，对所有数据重置，回到初始状态
function operator:reset()
    self._tweenBase:reset()
end

---销毁
---@param finish boolean 是否需要执行播放完成的相关事件
function operator:destroy(finish)
    manager:destroy(self._tweenBase, finish)
end

---销毁，但是当缓动无效时不会报错
---@param finish boolean 是否需要执行播放完成的相关事件
function operator:destroySafely(finish)
    if self:isValid() then
        self:destroy(finish)
    end
end

---注册一个回调函数，这个函数会在缓动开始时被调用
---@param callBack function
function operator:onStart(callBack, ...)
    self._tweenBase.params.onStart = callBack
    self._tweenBase.params.onStartArgs = table.pack(...)
    return self
end

---注册一个回调函数，这个函数会在缓动开始时被调用
---@param callBack function
function operator:onFinish(callBack, ...)
    self._tweenBase.params.onFinish = callBack
    self._tweenBase.params.onFinishArgs = table.pack(...)
    return self
end

---注册一个回调函数，这个函数会在缓动更新的每一帧调用
---@param callBack function
function operator:onUpdate(callBack, ...)
    self._tweenBase.params.onUpdate = callBack
    self._tweenBase.params.onUpdateArgs = table.pack(...)
    return self
end

return operator
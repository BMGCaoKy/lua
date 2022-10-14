local new = require "core.tools".new

local tweenManager = {}

local tweenerId = 0
local createdTweenList = {} ---@type table<any, TweenBase>
local createdCount = 0
local time = os.clock()
local timeScale = 1

local function getTID()
    tweenerId = tweenerId + 1
    return tweenerId
end

local function addToCreated(tid, tween)
    if createdTweenList[tid] then
        tweenManager:destroy(createdTweenList[tid])
    end

    createdTweenList[tid] = tween
    createdCount = createdCount + 1
end

local function calcDeltaTime()
    local realTime = os.clock() - time
    return realTime * timeScale
end

local function refreshTime()
    time = os.clock()
end

local function updateTween(deltaTime)
    for tid, tweener in pairs(createdTweenList) do
        if tweener.status:isInSequence() then
            goto continue
        end

        tweener:update(deltaTime)
        if tweener:canKill() then
            tweenManager:destroy(tweener)
        end

        ::continue::
    end
end

---@return Tweener
local function newTweener(getter, setter, to, duration, tid)
    local ctor = require "core.tween.tweener" ---@type fun() : Tweener
    local instance = ctor()
    instance:init(getter, setter, to, duration, tid)
    return instance
end

---@return Sequence
local function newSequence(tid)
    return new(require"core.sequence.sequence", tid)
end

---创建一个缓动，下一帧缓动开始执行
---@param getter fun():any 获取当前目标值，该值需要可以被运用于四则运算
---@param setter fun():any 设置当前目标值
---@param to any 一个终点值，需要支持四则运算
---@param duration number 本次缓动的执行时间
---@param tid any 传入一个缓动唯一标识，每次创建会检测是否存在该缓动，然后会停止旧的缓动
---@return TweenerOperator
function tweenManager:createTweener(getter, setter, to, duration, tid)
    if not to then
        perror("请输入目标值!", debug.traceback())
        return
    end

    if not duration then
        perror("请输入缓动时间!", debug.traceback())
        return
    end

    local tid = tid or getTID()
    local tweener = newTweener(getter, setter, to, duration, tid)

    addToCreated(tid, tweener)

    return tweener.operator
end

function tweenManager:createSequence(tid)
    local tid = tid or getTID()
    local sequence = newSequence(tid) ---@type Sequence

    addToCreated(tid, sequence)

    return sequence.operator
end

function tweenManager:createShaker()

end

---创建一个不做默认更新的缓动
function tweenManager:createUnburdenedTween(getter, setter, to, duration)
    if not duration then
        perror("请输入缓动时间!", debug.traceback())
        return
    end
    local tweener = newTweener(getter, setter, to, duration)
    return tweener.operator
end

function tweenManager:update()
    local deltaTime = 
    calcDeltaTime()
    refreshTime()

    updateTween(deltaTime)
end

---@param tween TweenBase
function tweenManager:destroy(tween, finish)
    tween:destroy()

    if finish then
        tween:finish()
    end

    --从管理容器中移除
    createdTweenList[tween:tid()] = nil
    createdCount = createdCount - 1
end

---@param tid string
function tweenManager:destroyTweenByTid(tid, finish)
    local tween = createdTweenList[tid]
    if not tween then
        return
    end
    self:destroy(tween, finish)
end

function tweenManager:setTimeScale(value)
    if value < 0 then
        print(error("Time Scale 不能设置 0 以下的数!"))
        return
    end

    timeScale = value
end

return tweenManager

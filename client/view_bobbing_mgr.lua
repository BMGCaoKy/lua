local bm = Blockman.instance
local gameSettings = bm.gameSettings

--[[
    rotateArray = [
        { // step 1
            rotate = {x = xx, y = xx, z = xx}, // 要旋转的目标角度（会从上一次的角度旋转到当前角度）
            count = xx, // 分几次旋转
            timerStep = xx, // timer计时器的间隔
        },
        {..}.. step n
    ]
--]]
local rotateBobbingHandleTable = {}
local rotateBobbing
local rotateBobbingTimer = nil
local function handleRotateBobbing()
    if rotateBobbingTimer then
        rotateBobbingTimer()
        rotateBobbingTimer = nil
    end
    local idx = rotateBobbingHandleTable.idx
    local rotateCfg = rotateBobbingHandleTable.rotateArray[idx]
    local lastRotateCfg = rotateBobbingHandleTable.rotateArray[idx - 1]
    if not rotateCfg then
        return
    end
    rotateBobbing(rotateCfg, lastRotateCfg or {})
    rotateBobbingHandleTable.idx = idx + 1
end
rotateBobbing = function(rotateCfg, lastRotateCfg)
    gameSettings.viewRotateBobbing = true
    local rotate = rotateCfg.rotate
    local lastRotate = lastRotateCfg.rotate or {x = 0, y = 0, z = 0}
    local count = rotateCfg.count
    local rotateStep = {x = (rotate.x - lastRotate.x) / count, y = (rotate.y - lastRotate.y) / count, z = (rotate.z - lastRotate.z) / count} 
    rotateBobbingTimer = World.Timer(rotateCfg.timerStep or 1, function()
        if count > 0 then
            count = count - 1
            lastRotate = {x = lastRotate.x + rotateStep.x, y = lastRotate.y + rotateStep.y, z = lastRotate.z + rotateStep.z}
            gameSettings:setViewRotateBobbingVec(lastRotate)
            return true
        end
        gameSettings.viewRotateBobbing = false
        handleRotateBobbing()
    end)
end
-- 测试代码 ViewBobbingMgr.viewRotateBobbing({{rotate = {x = 0, y = 0, z = 10}, count = 2},{rotate = {x = 0, y = 0, z = 0}, count = 50}})
function ViewBobbingMgr.viewRotateBobbing(rotateArray)
    if not rotateArray or (#rotateArray <= 0) then
        return
    end
    rotateBobbingHandleTable.rotateArray = rotateArray
    rotateBobbingHandleTable.idx = 1
    handleRotateBobbing()
end
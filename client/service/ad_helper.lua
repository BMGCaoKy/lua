---
--- 广告服务
--- 对外部开发者的提供的广告相关接口
---使用前，优先定义场景（临时限制9个场景，每个场景9个广告位即1-9索引）
--- DateTime: 2021/5/20 14:19
---

local AdHelper = {}
local adEnable = L("adEnable", false)
local videoAdStateChange = L("videoAdStateChange", {})
local adResultCalls = L("adResultCalls", {})
local adPlace = L("adPlace", {})
local lastReportPlace = L("lastReportPlace")

AdHelper.VideoAdResult = {
    FINISHED = 1,
    FAILED = 2,
    CLOSE = 3
}

---定义广告场景，客户端初始化时优先定义，确保每次定义的顺序保持一致
---@param place string 场景名称
function AdHelper:defineAdPlace(place)
    place = tostring(place) or "DEFAULT"
    if adPlace[place] then
        return
    end
    local index = #adPlace
    if index >= 9 then
        perror("The number of places must not exceed 9! \n", traceback())
        return
    end
    local placeId = index * 10 + 1
    adPlace[place] = placeId
    table.insert(adPlace, place)
end

---返回是否可以开启观看广告入口（有app决定有广告资源进行播放）
---@return boolean 是否开启观看广告入口
function AdHelper:canEnableVideoAd()
    return adEnable
end

---上报观看广告的场景，可指定场景，未指定场景id时自动生成并返回
---@param place string 指定场景
function AdHelper:reportAdPlace(place)
    if not adEnable then
        return
    end
    local placeId = adPlace[tostring(place)]
    if not placeId then
        perror("The place Undefined !", place)
        return
    end
    lastReportPlace = place --记录上一次上报场景
    Interface.onAppActionTrigger(12, tostring(placeId)) -- 上报广告场景
end

---播放广告
---@param place string 指定场景，若未指定如果之前上报过场景则使用之前的场景
---@param adIndex number 指定广告位置索引，取值范围 [1, 9],默认值 1
---@param callBack function 广告播放结果回调函数，参数1：VideoAdResult：播放广告结果， 参数2：place：场景名，参数3：index：广告位置索引
---@return function 取消结果回调函数执行的函数
function AdHelper:videoAd(place, adIndex, callBack)
    if not adEnable then
        return
    end
    place = place or lastReportPlace
    if place ~= lastReportPlace then
        self:reportAdPlace(place)
    end
    local placeId = place and adPlace[tostring(place)]
    if not placeId then
        perror("Place parameters must exist!", place)
        return
    end
    adIndex = adIndex or 1
    if adIndex < 1 or adIndex > 9 then
        perror("Index must be 1 to 9 !", adIndex)
        return
    end

    local adId = placeId - 1 + adIndex
    -- 播放广告
    CGame.instance:getShellInterface():onWatchAd(adId, "", tostring(placeId))
    adResultCalls[adId] = {
        callBack = callBack,
        place = place,
        index = adIndex
    }
    return function()
        adResultCalls[adId] = nil
    end
end

---注册观看广告入口状态改变的回调函数
---@param callBack function 回调函数
---@return function 取消执行回调的函数
function AdHelper:registerEnableVideoAdChange(callBack)
    local index = #videoAdStateChange + 1
    videoAdStateChange[index] = callBack
    return function()
        videoAdStateChange[index] = nil
    end
end

local function receiveEnableVideoAd()
    for _, callBack in pairs(videoAdStateChange) do
        Lib.XPcall(callBack, "AdHelper: error receiveEnableVideoAd!", adEnable)
    end
end

---private：改变广告入口状态（开启/关闭）
function AdHelper:enableVideoAd(enable)
    if adEnable == enable then
        return
    end
    adEnable = enable
    receiveEnableVideoAd()
end

---private：广告播放结果
function AdHelper:onVideoAdResult(adId, code)
    local call = adResultCalls[adId]
    adResultCalls[adId] = nil
    if not call or not call.callBack then
        return
    end
    Lib.XPcall(call.callBack, "AdHelper: error onVideoAdResult!", code, call.place, call.index)
end

local engine_module = require "common.engine_module"
engine_module.insertModule("AdHelper", AdHelper)

RETURN(AdHelper)
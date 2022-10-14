local Utils = require "common.api.util"

local function getWindowInstance(window)
	if(window) then
		return UI:getWindowInstance(window)
	else
		return nil
	end
end

local function setWindowInstance(instance)
	if(instance) then
		return instance:getWindow()
	else
		return nil
	end
end

local fieldMap =
{
	Layout = {get = "getLayoutFile", set = "setLayoutFile", setTypeFunc = Utils.CheckLayoutSuffix},
	AlwaysOnTop = {get = "getIsTop", set = "setIsTop"},
	AlwaysFaceCamera = {get = "getIsFaceCamera", set = "setIsFaceCamera"},
	ViewDistance = {get = "getRangeDistance", set = "setRangeDistance"},
	ScaleWithDistance = {get = "isScaleWithDistance", set = "setScaleWithDistance"},
	Position = {get = "getPosition", set = "setPosition", getTypeFunc = Utils.ToNewVector3},
	Rotation = {get = "getRotation", set = "setRotation", getTypeFunc = Utils.ToNewVector3},
	LockWorldRotation = {get = "getIsLock", set = "setIsLock"},
	-- 由于上一版Position和Rotation已经发布出去不能直接去掉， 下面的是这一版需求
	--LocalPosition = {get = "getPosition", set = "setPosition", getTypeFunc = Utils.ToNewVector3},
	--LocalRotation = {get = "getRotation", set = "setRotation", getTypeFunc = Utils.ToNewVector3},
}

if World.isClient then -- 暂时不分文件
	fieldMap.Window = {get = "getLayoutWindow", set = "setLayoutWindow", getTypeFunc = getWindowInstance, setTypeFunc = setWindowInstance}
end

APIProxy.RegisterFieldMap(fieldMap)

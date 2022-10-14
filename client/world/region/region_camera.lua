local RegionBase = require("world.region.region_base")
local RegionCamera = L("RegionCamera", Lib.derive(RegionBase))
local bm = Blockman.instance

RegionCamera.enter = 0

function RegionCamera:isVaild(viewSetting, entity)
	if not viewSetting or not viewSetting.personView then
		return
	end
	if not entity.isPlayer then
		return
	end
	return true
end

function RegionCamera:onEntityEnter(entity, cfg)
	local viewSetting = cfg.viewSetting
	if not viewSetting.personView then
		viewSetting.personView = bm:getCurrPersonView()
	end
	if not self:isVaild(viewSetting, entity) then
		return
	end
	if self.enter == 0 then
		self:saveCameraInfo(viewSetting)
	elseif self.enter > 0 then
		self:recoverCameraInfo()
	end
	self.enter = 1
	self:changeCamera(viewSetting)
end

function RegionCamera:onEntityLeave(entity, cfg)
	local viewSetting = cfg.viewSetting
	if not viewSetting.personView then
		viewSetting.personView = bm:getCurrPersonView()
	end
	if not self:isVaild(viewSetting, entity) then
		return
	end
	if self.enter > 0 then
		self:recoverCameraInfo(viewSetting)
	end
	self.enter = 0
end

function RegionCamera:saveCameraInfo(viewSetting)
	local cameraInfo = bm:getCameraInfo(viewSetting.personView)
	self.saveData = {
		curInfo = cameraInfo.curInfo,
		viewCfg = cameraInfo.viewCfg,
	}
end

function RegionCamera:recoverCameraInfo()
	local saveData = self.saveData
	if not saveData then
		return
	end
	local personView = bm:getCurrPersonView()
	bm:changeCameraCfg(saveData.viewCfg, personView)
	bm:setPersonView(saveData.curInfo.curPersonView)
	bm:setCanSwitchView(saveData.curInfo.canSwitchView)
	self.saveData = nil
end

function RegionCamera:changeCamera(viewSetting)
	local personView = viewSetting.personView
	local viewCfg = viewSetting.viewCfg
	local smoothView = viewSetting.smoothView
	local canSwitch = viewSetting.canSwitch
	bm:setPersonView(personView)
	if viewCfg then
		bm:changeCameraCfg(viewCfg, personView)
	end
	if smoothView then
		Player.CurPlayer:changeCameraView(smoothView.pos, smoothView.yaw, smoothView.pitch, smoothView.distance, smoothView.smooth)
	end
	if canSwitch ~= nil then
		bm:setCanSwitchView(canSwitch)
	end
end

RETURN(RegionCamera)
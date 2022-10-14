local setting = require "common.setting"

local CfgMod = setting:mod("dropitem")

DropItem.isDropItem = true

function DropItem:initData()
	Object.initData(self)
	local cfgName = self:getCfgName()
	local cfg = assert(CfgMod:get(cfgName), cfgName)
	self._cfg = cfg
end

function DropItem:item()
	return self:data("item")
end

function DropItem.GetCfg(cfgName)
    return assert(CfgMod:get(cfgName), cfgName)
end

function CfgMod:onLoad(cfg)
	World.CurWorld:loadDropItemConfig(cfg.id, cfg)
end

local function init()
	local defaultCfg = {
		id = 0,
		fullName = "/dropitem",
		width = 0.2,
		height = 0.5,
		pickedRadius = World.cfg.pickedRadius,
		viewDistance = World.cfg.dropitemViewDistance,
		collider = World.cfg.dropitemCollider,		
		disableClientTick = false;
		collision = false;
	}
	CfgMod:set(defaultCfg)
end

init()

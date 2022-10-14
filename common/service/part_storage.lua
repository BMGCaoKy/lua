local manager = World.CurWorld:getSceneManager()
local PartStorage = manager:getPartStorage()

local PARTSTORAGE_SETTING_PATH = "part_storage/setting.json"

function PartStorage.Init()
	local path = PARTSTORAGE_SETTING_PATH
	local partCfgs = Lib.readGameJson(path)

	if not partCfgs then
		return
	end

	for _, cfg in ipairs(partCfgs) do
		local subPart = Instance.newInstance(cfg)
		if subPart then
			subPart:setParent(PartStorage)
		end
	end
end

local function connectEvent(oIns, newIns)
	if oIns and newIns then
		newIns._cfg = oIns._cfg -- just ref
		if newIns._cfg and newIns._cfg.triggerSet then
			Instance.checkNeedConnectEvent(newIns, newIns._cfg.triggerSet)
		end
	end
end

local function clone(oIns)
	local newIns = oIns:clone()
	connectEvent(oIns, newIns)
	local oInsDescendants = oIns:getDescendants()
	local newInsDescendants = newIns:getDescendants()
	for i = 1, #oInsDescendants do
		connectEvent(oInsDescendants[i], newInsDescendants[i])
	end
	return newIns
end

function PartStorage:getFirstByInstanceName(name, recursive)
	local instance = PartStorage:findFirstChild(name, recursive)
	if instance then
		return clone(instance)
	else
		Lib.logError("Get instance failed from PartStorage, instanceName = ", name)
	end
end

function PartStorage:getByInstanceId(id)
	local instance = Instance.getByInstanceId(id)
	if instance and self:isAncestorOf(instance) then
		return clone(instance)
	else
		Lib.logError("Get instance failed from PartStorage, instanceId = ", id)
	end
end

local engine_module = require "common.engine_module"
engine_module.insertModule("PartStorage", PartStorage)

RETURN(PartStorage)
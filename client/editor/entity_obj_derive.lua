local engine = require "editor.engine"
local cjson = require "cjson"
local def = require "editor.def"
local data_state = require "editor.dataState"
local map_setting = require "editor.map_setting"
local birthPos = require "editor.entity_derive.birthPos"
local endPos = require "editor.entity_derive.endPos"
local vectorBlock = require "editor.entity_derive.vectorBlock"
local moveBlock = require "editor.entity_derive.moveBlock"
local buffItem = require "editor.entity_derive.buffItem"
local teleporter = require "editor.entity_derive.teleporter"
local monster = require "editor.entity_derive.monster"
local resPoint = require "editor.entity_derive.resPoint"
local box = require "editor.entity_derive.box"
local pointEntity = require "editor.entity_derive.pointEntity"
local savePoint = require "editor.entity_derive.savePoint"

local EntityObj = require "editor.entity_obj"

local queue = {} 
local allType = {
	birthPos = birthPos,
	endPos = endPos,
	teleporter = teleporter,
	moveBlock = moveBlock,
	monster = monster,
	vectorBlock = vectorBlock,
	buffItem = buffItem,
	resPoint = resPoint,
	box = box,
	pointEntity = pointEntity,
	savePoint = savePoint
}

function EntityObj:rulerArithmeticAdd(cfgName, pos, id)
	local needInit = id and true or false
    local entityCfg = Entity.GetCfg(cfgName)
	local maxCount = entityCfg.maxCount
    if not maxCount then
        return
    end
	if not queue[cfgName] then
		queue[cfgName] = {}
		queue[cfgName].info = {}
		queue[cfgName].entityData = {}
		queue[cfgName].info.head = 1
		queue[cfgName].info.tail = 1
	end
	local head = queue[cfgName].info.head
	local tail = queue[cfgName].info.tail
	local headId = queue[cfgName].entityData[head] and queue[cfgName].entityData[head].id or nil
	if not needInit then
		id = self:addEntity(pos, {
			cfg = cfgName
		})
	end
	if tail - head >= maxCount then
		self:delEntity(headId)
		queue[cfgName].info.head = queue[cfgName].info.head + 1
	end
	queue[cfgName].entityData[tail] = {
		pos = pos,
		id = id,
		cfg = cfgName
	}
	queue[cfgName].info.tail = queue[cfgName].info.tail + 1
	return id
end

function EntityObj:rulerArithmeticSub(cfgName)
	if not queue[cfgName] then
		return
	end
	queue[cfgName].info.tail = queue[cfgName].info.tail - 1
	queue[cfgName].info.head = queue[cfgName].info.head - 1
	local head = queue[cfgName].info.head
	if queue[cfgName].info.head >= 1 then

		local pos = queue[cfgName].entityData[head].pos
		local cfg = queue[cfgName].entityData[head].cfg
		local id = self:addEntity(pos, {
			cfg = cfg
		})
		queue[cfgName].entityData[head] = {
			pos = pos,
			id = id,
			cfg = cfgName
		}
		engine:recently_entity(self:getCfgById(id))

	else
		queue[cfgName].info.head = 1
	end
	local tail = queue[cfgName].info.tail
	if tail >= 1 then
		self:delEntity(queue[cfgName].entityData[tail].id)
	else
		queue.cfg.info.tail = 1
	end
end

function EntityObj:ruleExternDel(cfgName, id)
	if not queue[cfgName] then
		return
	end
	local head = queue[cfgName].info.head
	local tail = queue[cfgName].info.tail
	local resultIndex
	for i = head, tail - 1 do
		local targetId = queue[cfgName].entityData[i].id
		if tostring(id) == tostring(targetId) then
			resultIndex = i
			break
		end
	end
	if not resultIndex then
		return
	end
	queue[cfgName].info.tail = queue[cfgName].info.tail - 1
	if tail >= 1 then
		self:delEntity(queue[cfgName].entityData[resultIndex].id)
	else
		queue[cfgName].info.tail = 1
	end
	table.remove(queue[cfgName].entityData, resultIndex)
	return resultIndex
end

function EntityObj:ruleExternInsert(cfgName, pos, insertIndex)
	if not insertIndex or insertIndex <= 0 then
		return
	end

	if not queue[cfgName] then
		return
	end
	
	local head = queue[cfgName].info.head
	local tail = queue[cfgName].info.tail
	queue[cfgName].info.tail = queue[cfgName].info.tail + 1
	local id = self:addEntity(pos, {
		cfg = cfgName
	})
	table.insert(queue[cfgName].entityData, insertIndex, {
		pos = pos,
		id = id,
		cfg = cfgName
	})

	return id
end

function EntityObj:clearCustomData()
	queue = {}
	for k, v in pairs(self.entity or {}) do
		v:destroy()
	end
	self.entity = {}
end

-- 最后要按照这个统一下接口
function EntityObj:getDeriveType(id)
	local name = self:getCfgById(id)
	local settingCfg = Entity.GetCfg(name)
	return settingCfg.entityDerive
end

function EntityObj:deriveLoadEntity(id, ...)
	local typeF = self:getDeriveType(id)
	if not typeF then
		return
	end
	local func = allType[typeF].load
	if func then
		func(self, id, ...)
	end
end

function EntityObj:deriveEmptyClick(id, ...)
	local typeF = self:getDeriveType(id)
	if not typeF then
		return
	end
	local func = allType[typeF].click
	if func then
		func(self, id, ...)
	end
end

function EntityObj:deriveSetData(id, key, value)
	local typeF = self:getDeriveType(id)
	if not typeF then
		return
	end
	local func = allType[typeF].set
	if func then
		func(self, id, key, value)
	end
end

local M = {}


function EntityObj:Cmd(cmd, id, ...)
	local typeF = self:getDeriveType(id)	
	if not typeF then
		return
	end
	local derive_obj = self:getDataById(id)
	local func = allType[typeF][cmd]
	if func then
		--derive_obj.type = typeF
		return func(self, id, derive_obj, ...)
	end
end

function EntityObj:allMapCmd(cmd, typeF, id, derive_obj, ...)
	if not typeF then
		return
	end
	local func = allType[typeF][cmd]
	if func then
		return func(self, id, derive_obj, ...)
	end
end

function EntityObj:deriveAddEntity(id, ...)
	local typeF = self:getDeriveType(id)
	if not typeF then
		return
	end
	local derive_obj = self:getDataById(id)
	local func = allType[typeF].add
	if func then
		--derive_obj.type = typeF
		func(self, id, derive_obj, ...)
	end
end

function EntityObj:deriveDelEntity(id)
	local typeF = self:getDeriveType(id)
	if not typeF then
		return
	end
	local derive_obj = self:getDataById(id)
	local func = allType[typeF].del
	if func then
		func(self, id, derive_obj)
	end
end

function EntityObj:CmdCanRedoSet(cfg, ...)
	local settingCfg = Entity.GetCfg(cfg)
	local typeF = settingCfg.entityDerive
	if not typeF then
		return true
	end
	local func = allType[typeF].canRedoSet
	if not func then
		return true
	end
	return func(self, cfg, ...)
end

function EntityObj:CmdCanUndoSet(cfg, ...)
	local settingCfg = Entity.GetCfg(cfg)
	local typeF = settingCfg.entityDerive
	if not typeF then
		return true
	end
	local func = allType[typeF].canUndoSet
	if not func then
		return true
	end
	return func(self, cfg, ...)
end

function EntityObj:CmdRedoSet(pos, cfg, cmdSet)
	local settingCfg = Entity.GetCfg(cfg)
	local typeF = settingCfg.entityDerive
	if not typeF then
		return false
	end
	local func = allType[typeF].redoSet
	if not func then
		return false
	end
	return func(self, pos, cfg, cmdSet)
end

function EntityObj:CmdUndoSet(cfg, cmdSet)
	local settingCfg = Entity.GetCfg(cfg)
	local typeF = settingCfg.entityDerive
	if not typeF then
		return false
	end
	local func = allType[typeF].undoSet
	if not func then
		return false
	end
	return func(self, cfg,cmdSet)
end

function EntityObj:CmdCanRedoDel(cfg)
	local settingCfg = Entity.GetCfg(cfg)
	local typeF = settingCfg.entityDerive
	if not typeF then
		return true
	end
	local func = allType[typeF].canRedoDel
	if not func then
		return true
	end
	return func(self, cfg)
end

function EntityObj:CmdCanUndoDel(cfg)
	local settingCfg = Entity.GetCfg(cfg)
	local typeF = settingCfg.entityDerive
	if not typeF then
		return true
	end
	local func = allType[typeF].canUndoDel
	if not func then
		return true
	end
	return func(self, cfg)
end

function EntityObj:CmdRedoDel(cfg, cmdDel)
	local settingCfg = Entity.GetCfg(cfg)
	local typeF = settingCfg.entityDerive
	if not typeF then
		return false
	end
	local func = allType[typeF].redoDel
	if not func then
		return false
	end
	return func(self, cmdDel)
end

function EntityObj:CmdUndoDel(cfg, cmdDel)
	local settingCfg = Entity.GetCfg(cfg)
	local typeF = settingCfg.entityDerive
	if not typeF then
		return false
	end
	local func = allType[typeF].undoDel
	if not func then
		return false
	end
	return func(self, cmdDel)
end
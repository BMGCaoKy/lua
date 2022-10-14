require "common.world"
require "entity.entity"
local cjson = require "cjson"
local engine = require "editor.engine"
local data_state = require "editor.dataState"
local map_setting = require "editor.map_setting"
local globalSetting = require "editor.setting.global_setting"
local createEntityTimers = {}
local EntityObj = {}

local function clearAllEntity(self)
	self:clearAllCreateEntityTimers()
	local curMap = self.curMap
	local allEntitys = self.allEntitys[curMap]
	if not allEntitys then
		return
	end
	self:clearCustomData()
	for _, entity_obj in pairs(allEntitys.entitys or {}) do
		SceneUIManager.RemoveEntityHeadUI(entity_obj.objID)
		entity_obj:destroy()
	end
	allEntitys.entitys = {}
end

local function createAllEntity(self)
	local allEntitys = self.allEntitys[self.curMap]
	for id, obj in pairs(allEntitys.datas or {}) do
		local entity = EntityClient.CreateClientEntity({
			cfgName=obj.cfg,
			pos=obj.pos,
			ry=obj.ry
		})
		allEntitys.entitys[id] = entity
		self:deriveLoadEntity(id, obj.pos, entity)
	end
end

local function loadEntity(self)
	clearAllEntity(self)
	local curMap = data_state.now_map_name
	self.curMap = curMap
	if self.allEntitys[curMap].entitys then
		createAllEntity(self)
		return
	end
	local entitys = {}
	local datas = {}
	local len = 0
	local item
	local content = self.allEntitys[curMap].datas
    if not content then
        content = {}
	end
	self.allEntitys[curMap].entitys = entitys
	for id = 1, #content do
		local obj = {
			pos = content[id].pos,
			ry = content[id].ry,
			cfg = content[id].cfg,
			derive = content[id].derive
		}
		createEntityTimers[id] = World.LightTimer("load entity", 5, function()
			local pos = Player.CurPlayer:getPosition()
			local cfg = Entity.GetCfg(obj.cfg)
			if Lib.getPosDistanceSqr(pos, content[id].pos) > 400 and cfg and not cfg.dontCreateDynamically then
				return true
			end
			entitys[id] = EntityClient.CreateClientEntity({
				cfgName = obj.cfg,
				pos = obj.pos,
				ry = obj.ry
			})
			for key, value in pairs(entitys[id]:cfg().passiveBuffs or {}) do
				entitys[id]:addClientBuff(value.name, value.time)
			end
			self:deriveLoadEntity(id, obj.pos, entitys[id])
			if Entity.GetCfg(obj.cfg) and Entity.GetCfg(obj.cfg).showBoundBox then
				entitys[id]:setRenderBox(true)
				local color = Entity.GetCfg(obj.cfg).boundBoxColor
				entitys[id]:setRenderBoxColor(color and {color[1], color[2], color[3], color[4]} or {1, 1, 1, 1})
			end
		end)
	end
	self.allEntitys[curMap].len = #content
end

function EntityObj:loadDataByMapName(mapName)
	local obj = {}
	obj.datas = {}
	local entityData = map_setting:getEntitysByMapName(mapName)
	local index = 1
	for _, entityDataObj in pairs(entityData or {}) do
		obj.datas[index] = {
			pos = entityDataObj.pos,
			ry = entityDataObj.ry,
			cfg = entityDataObj.cfg,
			derive = entityDataObj.derive
		}
		obj.len = index
		obj.dirty = false
		index = index + 1
	end
	self.allEntitys[mapName] = obj
end

function EntityObj:init()
	local function getAllMapName()
		local ret = {}
		local rootPath = Root.Instance():getGamePath().. "map/"
		for fileName in lfs.dir(Root.Instance():getGamePath().. "map/") do
			if fileName ~= "." and fileName ~= ".." and fileName ~= "patchDir" then
				local fileattr = lfs.attributes(rootPath .. fileName, "mode", true)
				if fileattr == "directory" then
					ret[#ret + 1] = fileName
				end
			end
		end
		return ret
	end
	self.allEntitys = {}
	self.curMap = nil
	local allMapName = getAllMapName()
	for _, mapName in pairs(allMapName) do
		self:loadDataByMapName(mapName)
	end

	Lib.subscribeEvent(Event.EVENT_TEAM_SETTING_CHANGE, function()
		self:allCmd("changeTeamId", function(params)
			local cfg = params.cfg
			if cfg.entityDerive == "box" then
				return true
			end
			return false
		end)
	end)
end

function EntityObj:load()
	local mapName = data_state.now_map_name
	local obj = self.allEntitys[mapName]
	if not obj then
		-- new map
		self:loadDataByMapName(mapName)
		obj = self.allEntitys[mapName]
	end
	obj.dirty = true
	loadEntity(self)
end

function EntityObj:save(path)
	map_setting:save_entitys(self.allEntitys)
end

function EntityObj:delPointEntity() --todo multi map
    local curMap = self.curMap
	local allEntitys = self.allEntitys[curMap]
	if not allEntitys then
		return
	end
	for k, entity_obj in pairs(allEntitys.entitys or {}) do
        local derive = self:getDataById(k)
        if derive and derive.pointEntity then
            self:delEntity(k)
        end
	end
end

function EntityObj:buildPointEntity()
    local entitys = self:getPointEntity()
    for key, data in ipairs(entitys or {}) do
        local tb = {cfg = data.cfg, derive = 
            {pointEntity = {idx = data.idx, teamId = data.teamId or 0, type = "pointEntity", entity = data.entity, typePoint = data.typePoint}}}
        local pos
        
        if next(data.pos or {}) then
            if self.curMap ~= data.pos.map then
                goto continue
            end
            pos = {x = data.pos.x, y = data.pos.y, z = data.pos.z, ry = data.ry or 0}
        end
        if pos then
		    self:addEntity(pos, tb)
        end
		::continue::
    end
end

function EntityObj:getPointEntity()
    local teams = globalSetting:getTeamMsg() or {}
    local entitys = {}
    if #teams > 0 then
        for teamId, team in ipairs(teams) do
            if next(team.startPos or {}) then
                local birthObj = {pos = team.startPos[1],
                             typePoint = 3,  --3=team birth point
                             teamId = teamId,
                             idx = 1,
                             cfg = "myplugin/door_entity_setPos_birth"}
                table.insert(entitys, birthObj)
            end
            if next(team.rebirthPos or {}) then
                local rebirthObj = {pos = team.rebirthPos[1],
                             typePoint = 4, --4= team rebirth point
                             teamId = teamId,
                             idx = 1,
                             cfg = "myplugin/door_entity_setPos_rebirth"}
                table.insert(entitys, rebirthObj)
            end
                               
            if team.bed and team.bed.enable then
                local color = "_" .. string.lower(team.color)
                local bedPoint = {pos = team.bed.pos, ry = team.bed.ry, typePoint = 5, cfg = team.bed.entity .. color,entity = team.bed.entity, teamId = teamId, idx = 1}
                table.insert(entitys, bedPoint)
            end
        end
    else
        local startPos = globalSetting:getStartPos() or {}
        local rebirthPos = globalSetting:getRevivePos() or {}
        for key, pos in pairs(startPos) do
            local birthPoint = {pos = pos, typePoint = 1, teamId = 0, idx = key, cfg = "myplugin/door_entity_setPos_birth"}
            table.insert(entitys, birthPoint)
        end
        for key, pos in pairs(rebirthPos) do
            local rebirthPoint = {pos = pos, typePoint = 2, teamId = 0, idx = key, cfg = "myplugin/door_entity_setPos_rebirth"}
            table.insert(entitys, rebirthPoint)
        end
    end
	local initPos = globalSetting:getInitPos() or {}
	if next(initPos or {}) and not initPos.default then
		local initPoint = {pos = initPos, typePoint = 7, teamId = 0, idx = 1, cfg = "myplugin/door_entity_wait_point"}
		table.insert(entitys, initPoint)
	end
    return entitys
end

function EntityObj:overMaxCount(cfg, pos, id)
	self:rulerArithmeticAdd(cfg, pos, id)
end

function EntityObj:addEntity(pos, _table)
	local cfg = _table.cfg
	local allEntitys = self.allEntitys[self.curMap]	
	local entityObject = EntityClient.CreateClientEntity({cfgName = cfg, pos = pos, ry = pos.ry or 0})
    for key, value in pairs(entityObject:cfg().passiveBuffs or {}) do
        entityObject:addClientBuff(value.name, value.time)
    end
	local len = allEntitys.len

	len = len + 1
	allEntitys.len = len
	local obj = {
		pos = pos,
		ry = pos.ry or 0,
		pitch = 0,
		cfg = cfg,
		derive = _table.derive or {}
	}
	allEntitys.datas[len] = obj
	allEntitys.entitys[len] = entityObject
	engine:on_new_entity(tostring(len), obj)
	self:deriveAddEntity(len, pos, _table)
    if Entity.GetCfg(obj.cfg) and Entity.GetCfg(obj.cfg).showBoundBox then
        entityObject:setRenderBox(true)
        local color = Entity.GetCfg(obj.cfg).boundBoxColor
        entityObject:setRenderBoxColor(color and {color[1], color[2], color[3], color[4]} or {1, 1, 1, 1})
    end
	return allEntitys.len
end

function EntityObj:delEntity(id)
	local allEntitys = self.allEntitys[self.curMap]	
	local obj = allEntitys.datas[id]
	if obj then
		local cfg = obj.cfg
		local pos = obj.pos
		self:deriveDelEntity(id)
		allEntitys.entitys[id]:destroy()
		allEntitys.datas[id] = nil
		allEntitys.entitys[id] = nil
		engine:on_del_entity(tostring(id))
	end
end

function EntityObj:delEntityByFullName(fullName)
	if not fullName then
		return
	end

	local entitys = self.allEntitys[self.curMap].entitys
	for k, entity in pairs(entitys) do
		if entity:cfg().fullName == fullName then
			self:delEntity(k)
			return
		end
	end
end

function EntityObj:delEntityByDeriveType(deriveType, idx)
	for k, v in pairs(self.allEntitys[self.curMap].entitys) do
        local derive = self:getDataById(k)
        if derive and derive.pointEntity and derive.pointEntity.typePoint == deriveType then
            if not idx or (idx and (idx == derive.pointEntity.idx)) then
                self:delEntity(k)
            end
        end
	end
end

function EntityObj:getCfgById(id)
	return self.allEntitys[self.curMap].datas[id].cfg
end

function EntityObj:setCfgById(id, cfg)
	self.allEntitys[self.curMap].datas[id].cfg = cfg
end

function EntityObj:getPosById(id)
	local data = self.allEntitys[self.curMap].datas[id]
	return data and data.pos or nil
end

function EntityObj:getCurMapEntities()
	return self.allEntitys[self.curMap].datas
end

function EntityObj:getEntityById(id)
	return self.allEntitys[self.curMap].entitys[id]
end

function EntityObj:getEntityByFullName(fullName)
	if not fullName then
		return
	end

	local entitys = self.allEntitys[self.curMap].entitys
	local ret_entity
	for _, entity in pairs(entitys) do
		if entity:cfg().fullName == fullName then
			ret_entity = entity
			break
		end
	end
	return ret_entity
end

function EntityObj:getEntityByDeriveType(deriveType, idx, teamId)
    for k, v in pairs(self.allEntitys[self.curMap].entitys) do
        local derive = self:getDataById(k)
        if derive and derive.pointEntity and derive.pointEntity.typePoint == deriveType then
			if teamId == idx and teamId > 0 and teamId == derive.pointEntity.teamId then
				return v
			end
            if idx == derive.pointEntity.idx and teamId == derive.pointEntity.teamId then
                return v
            end
        end
	end
    return nil
end

function  EntityObj:getEntitysByDeriveTypeAndTeamID(types, teamId)
	local ret = {}
	local filter = {}
	local count = 1
	for _, k in pairs(types or {}) do
		filter[k] = true
	end
    for k, v in pairs(self.allEntitys[self.curMap].entitys) do
		local derive = self:getDataById(k)
        if derive and derive.pointEntity and (not teamId or teamId == derive.pointEntity.teamId) then
            local type = derive.pointEntity.typePoint
            if type and filter[type] then
                ret[count] = v
                count = count + 1
            end
        end
	end
    return ret
end

function EntityObj:setPosById(id, pos, is_send_update)
	local allEntitys = self.allEntitys[self.curMap]	
	local entity = allEntitys.entitys[id]
	local data = allEntitys.datas[id]
	assert(entity and data)
	entity:setPos(pos.pos, pos.ry)
	entity:setBodyYaw(pos.ry)
	data.pos = pos.pos
	data.ry = entity:getRotationYaw()
	if is_send_update then
		engine:on_update_entity(id, pos.pos, pos.ry, pos.pitch)
	end
end

function EntityObj:getIdByEntity(entity)
	for k,v in pairs(self.allEntitys[self.curMap].entitys) do
		if entity.objID == v.objID then
			return k
		end
	end
	return nil
end

function EntityObj:getYawById(id)
	local data = self.allEntitys[self.curMap].datas[id]
	return data and data.ry or nil
end

function EntityObj:setYawById(id, yaw)
	local data = self.allEntitys[self.curMap].datas[id]
	if data then
		local entity = self:getEntityById(id)
		entity:setRotationYaw(yaw)
		entity:setBodyYaw(yaw)
		data.ry = yaw
	end
end

function EntityObj:getPitchById(id)
	local data = self.allEntitys[self.curMap].datas[id]
	return data and data.pitch or nil
end

function EntityObj:delete_map(mapName)
	self.allEntitys[mapName] = nil
end

function EntityObj:rename_map(oldName, newName)
	local allEntitys = self.allEntitys
	if allEntitys[oldName] then
		allEntitys[newName] = allEntitys[oldName]
		allEntitys[oldName] = nil
	end
end

function EntityObj:getDataById(id)
	local entityData = self.allEntitys[self.curMap].datas[id]
	return entityData and entityData.derive or nil
end

function EntityObj:setDataById(id, value)
	local entityData = self.allEntitys[self.curMap].datas[id]
	if entityData then
		entityData.derive = value
	end
end

function EntityObj:getAllDataById(id)
	return self.allEntitys[self.curMap].datas[id]
end

function EntityObj:setEntityById(id, entity)
	local killEntity = self.allEntitys[self.curMap].entitys[id]
	if killEntity then
		killEntity:destroy()
	end
	self.allEntitys[self.curMap].entitys[id] = entity
	self:setCfgById(id, entity:cfg().fullName)
end

-- 这个接口
function EntityObj:allEntityCmd(cmd, filterFunc,...)
	local entitys = self.allEntitys[self.curMap].entitys
	for id, entity in pairs(entitys) do
		if not filterFunc or filterFunc(entity) then
			self:Cmd(cmd, id, ...)
		end
	end
end

function EntityObj:allCmd(cmd, filterFunc,...)
	for mapName, mapObj in pairs(self.allEntitys) do
		local datas = mapObj.datas
		for id, data in pairs(datas) do
			local name = data.cfg
			local cfg = Entity.GetCfg(name)
			local deriveData = data.derive
			if filterFunc({
				cfg = cfg,
				deriveData = deriveData	
			}) then
				self:allMapCmd(cmd, cfg.entityDerive, id, deriveData, ...)
			end
		end
	end
end

function EntityObj:clearAllCreateEntityTimers()
	for key, timer in pairs(createEntityTimers) do
		timer()
		createEntityTimers[key] = nil
	end
end
EntityObj:init()

return EntityObj
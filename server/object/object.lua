local setting = require "common.setting"

local AURA_MASK = Object:getTypeMask{"EntityServer", "EntityServerPlayer"}

local function auraCheckEntity(self, aura, entity)
	if aura.toPlayer~=nil and aura.toPlayer~=entity.isPlayer then
		return false
	end
	if aura.toEnemy~=nil and self.isEntity and aura.toEnemy~=self:canAttack(entity) then
		return false
	end
	if aura.toTeam then
		if not entity:getTeam() or entity:getTeam().id ~= aura.toTeam then
			return false
		end
	end
	return true
end

local function auraAddEntityBuff(self, aura, entity, buffName)
	local entitylist = aura.entitylist
	if entitylist[entity]~=nil then
		return
	end
	if auraCheckEntity(self, aura, entity) then
		entitylist[entity] = entity:addBuff(buffName,nil,self)
	else
		entitylist[entity] = false	-- 在光环内，但不满足筛选条件
	end
end

function Object:addAura(name, info)
	local auralist = self:data("aura")
	assert(not auralist[name], name)
	local aura = Lib.copyTable1(info)
	if aura.cfgName then
		local cfg = setting:fetch("aura", aura.cfgName)
		setmetatable(aura, {__index=cfg})
	end
	local range = math.floor((aura.range or 5) / 1)  -- 整除，为了取整
	if range<0 then
		range = 0
	end
	local rangelist = self:data("aurarange")
	local rangedata = rangelist[range]
	local newCreated = false
	if not rangedata then
		rangedata = {
			range = range,
			list = {},
		}
		rangelist[range] = rangedata
		-- 使用range作为id，同range的多个光环公用一个检测范围对象
		self:createObjectSphere(range, range, math.min(range*1.2, range + 1.5), AURA_MASK, {x = 0, y = 0, z = 0})
		newCreated = true
	end
	aura.name = name
	aura.from = self
	aura.range = range
	aura.rangedata = rangedata
	aura.entitylist = {}
	rangedata.list[name] = aura
	auralist[name] = aura
	if self.isEntity then
		local buffName = aura.selfBuffName or aura.buffName
		if buffName and buffName~="" then
			auraAddEntityBuff(self, aura, self, buffName)
		end
	end
	if newCreated then	-- 新建的会在后面回调通知新加入entity
		return aura
	end
	local buffName = aura.buffName
	if not buffName or buffName=="" then
		return aura
	end
	for _, entity in ipairs(self:getObjectSphereInside(range)) do
		if entity~=self then
			auraAddEntityBuff(self, aura, entity, buffName)
		end
	end
	return aura
end

function Object:removeAura(name)
	local auralist = self:data("aura")
	local aura = auralist[name]
	if not aura then
		return false
	end
	auralist[name] = nil
	local list = aura.rangedata.list
	list[name] = nil
	if not next(list) then
		self:data("aurarange")[aura.range] = nil
		self:removeObjectSphere(aura.range)
	end
	for entity, buff in pairs(aura.entitylist) do
		if buff and entity:isValid() then
			entity:removeBuff(buff)
		end
	end
	aura.rangedata = nil
	aura.entitylist = nil
	return aura
end

function Object:call_sphereChange(id, list)
	local rangedata = self:data("aurarange")[id]
	if not rangedata then
		return
	end
	for _, tb in ipairs(list) do
		local entity = tb[1]
		if entity~=self then
			if tb[2] then
				for _, aura in pairs(rangedata.list) do
					local buffName = aura.buffName
					if buffName and buffName~="" then
						auraAddEntityBuff(self, aura, entity, buffName)
					end
				end
			else
				for _, aura in pairs(rangedata.list) do
					local buff = aura.entitylist[entity]
					if buff then
						entity:removeBuff(buff)
					end
					aura.entitylist[entity] = nil
				end
			end
		end
	end
end

-- 当自身条件变化时，刷新自己的光环
function Object:refreshSelfAura()
	-- 用.luaData而不是:data()，避免过多的生成无用的table
	for _, aura in pairs(self.luaData.aura or {}) do
		for entity, buff in pairs(aura.entitylist) do
			if buff then
				if not auraCheckEntity(self, aura, entity) then
					self:removeBuff(buff)
					aura.entitylist[self] = false
				end
			elseif buff==false then
				if auraCheckEntity(self, aura, entity) then
					aura.entitylist[entity] = entity:addBuff(aura.buffName)
				end
			end
		end
	end
end

---@type setting
local setting = require "common.setting"

---@field getRotationPitch fun(self : Entity) : number
---@field getRotationYaw fun(self : Entity) : number
---@field getRotationRoll fun(self : Entity) : number
---@field getPosition fun(self : Entity) : Vector3
---@field getBoundingBox fun(self : Entity) : table<number, Vector3>
---@field setBoundingVolume fun(self : Entity, config : table) : void
---@field getBoolProperty fun(self : Entity, key : string) : boolean
---@field setBoolProperty fun(self : Entity, key : string, value : boolean) : void
---@field getIntProperty fun(self : Entity, key : string) : number
---@field setIntProperty fun(self : Entity, key : string, value : number) : void
---@field getFloatProperty fun(self : Entity, key : string) : number
---@field setFloatProperty fun(self : Entity, key : string, value : number) : void
---@field getStringProperty fun(self : Entity, key : string) : string
---@field setStringProperty fun(self : Entity, key : string, value : string) : void
---@field objID number
---@class Object
local Object = Object

Object.isMainPlayer = false
Object.isEntity = false
Object.isPlayer = false
Object.isDropItem = false
Object.isMissile = false

local type = type

local ObjectDef = {
	"Object",
	"Entity",
	"EntityClient",
	"EntityClientMainPlayer",
	"EntityServer",
	"EntityServerPlayer",
	"DropItem",
	"DropItemClient",
	"DropItemServer",
	"Missile",
	"MissileClient",
	"MissileServer",
}

local TypeID = T(Object, "TypeID")
for i, name in ipairs(ObjectDef) do
	TypeID[name] = i
end

function Object:initData()
	self.removed = false
	self.luaData = {}
	--self.components = {} ---@type table<string, Component> @组件列表
	function self.timerFunc(func, ...)
		if not self.removed then
			return func(...)
		end
	end
end

function Object:getTypeMask(types)
	local mask = 0
	for _, typ in ipairs(types) do
		local id = assert(TypeID[typ], typ)
		mask = Bitwise64.Or(mask, Bitwise64.Sl(1, id - 1))
	end
	return mask
end

local envMT = {
	__index = compat.getEnv(),
	__newindex = compat.getEnv(),
}
function Object:onCreate()
	local cfg = self:cfg()
	local luaList = cfg.luaList
	if luaList then
		local isClient = World.isClient
		local env = setmetatable({ object=self }, envMT)
		for _, tb in ipairs(luaList) do
			if tb[2] == nil or tb[2] == isClient then
				local path = Root.Instance():getGamePath() .. setting:relativePath(cfg, tb[1])
				local content = Lib.read_file(path)
				assert(load(content, "@"..path, "bt",env))(path)
			end
		end
	end
end

---@class Cfg
---@field fullName string
---@return Cfg
function Object:cfg()
    return self._cfg
end

function Object:data(key)
    local data = self.luaData
    local dat = data[key]
    if not dat then
        dat = {}
        data[key] = dat
    end
    return dat
end

function Object:setData(key, val)
	self.luaData[key] = val
end

function Object:timer(time, ...)
	return World.ObjectTimer(time, self.timerFunc, self, ...)
end

function Object:lightTimer(stack, time, ...)
	return World.LightTimer(stack, time, self.timerFunc, ...)
end

function Object:distance(obj)
	local p1 = self:getPosition()
	local p2 = obj:getPosition()
	if not p1 or not p2 or not self.map or not obj.map or self.map.id ~= obj.map.id then
		return math.huge
	end
	local x, y, z = p1.x-p2.x, p1.y-p2.y, p1.z-p2.z
	return math.sqrt(x*x + y*y + z*z)
end

function Object:distanceSqr(obj)
	return Lib.getPosDistanceSqr(self:getPosition(), obj:getPosition())
end

function Object:isValid()
	return not self.removed
end

function Object:addTracker(tracker)
	-- 已经被删除了
	if not self.map then
		return
	end

	if self.isPlayer then
		self.map.newspawnPlayers = self.map.newspawnPlayers or {}
		self.map.newspawnPlayers[self.objID] = true
	else
		self.map.newspawnEntities = self.map.newspawnEntities or {}
		self.map.newspawnEntities[self.objID] = true
	end
	self.trackers = self.trackers or {}
	self.trackers[tracker.objID] = true
end

function Object:getTrackers()
	return self.trackers
end

function Object:removeTrackers()
	self.trackers = nil
end

function Object:setMap(newMap)
	local oldMap = self.map
	if newMap == oldMap then
		return false
	end
	if oldMap and oldMap.leaveObject then
		oldMap:leaveObject(self, newMap)
	end
	self.map = newMap
	if not newMap then
		self:setMapID(0)
		return true
	end
	if self.willDestroy then
		Lib.logWarning(" set object map, but the obj will destroy . \n", traceback())
		return true
	end
	self:setMapID(newMap.id)
	newMap:joinObject(self, oldMap)
	return true
end

function Object:reconnectSetMap()
	local map = self.map
	self:setMapID(0)
	self:setMapID(map.id)
	return true
end

function Object:onLeaveMap(map)
end

function Object:onEnterMap(map)
end

function Object:destroy()
	assert(not self.removed)
	if self.onDestroy then
		self:onDestroy()
	end
	self.willDestroy = true
	local data = self.luaData
	while data.delaycall do
		local funcs = data.delaycall
		data.delaycall = nil
		for func in pairs(funcs) do
			func(self)
		end
	end
	if World.isClient then
		Blockman.instance:resetMouseOverInfo(self.objID)
	end
	self:setMap(nil)
	self.world:removeObject(self)
	--self:clearData()
	self.removed = true
end

function Object:delayCall(func, time)
	local funcs = self:data("delaycall")
	if funcs[func] then
		return
	end
	funcs[func] = true
	self:timer(time or 1, self.doDelayCall, self, func)
end

function Object:doDelayCall(func)
	self:data("delaycall")[func] = nil
	func(self)
end

-- object's aabb box cast test
function Object:aabbSweepClosest(dstPosition, collisionMask, yoffSet)
	yoffSet = yoffSet or 0.05 -- 碰撞体贴地时，BoundingBox可能与地面有碰撞，要稍抬高碰撞体，或者有爬坡检测需要时设置yoffSet
	local aabb = self:getBoundingBox()
	if not aabb or aabb[1] ~= 1 then -- not EXTENT_FINITE
		return false
	end
	local vMin, vMax = aabb[2], aabb[3]
	local halfExtent = (vMax - vMin) / 2
	local fromPosition = vMin + halfExtent--self:getPosition()
	local dir = dstPosition - self:getPosition()--fromPosition
	fromPosition.y = fromPosition.y + yoffSet
	halfExtent.z = 0 -- 设置前向厚度为0
	local rs = self.map:getPhysicsWorld():shapeCast({type = "Box", extent = halfExtent}, fromPosition,
		--[[self:getAxisRotation()]]Quaternion.fromVectorRotation(Lib.v3(0, 0, 1), dir), dir, dir:len(), collisionMask)
	return rs
end

function Object:aabbSweepTest(dstPosition, collisionMask)
	local rs = self:aabbSweepClosest(dstPosition, collisionMask)
	-- :debug:
	-- if rs.targetType ~= 0 then
	-- 	local obj = rs.target
	-- 	local objId = rs.objID
	-- 	if objId then
	-- 		local objt = World.CurWorld:getObject(objId)
	-- 		local name = objt.name
	-- 	end
	-- end
	return rs and rs.targetType ~= 0
end

function object_call(obj, name, ...)
	local func = obj[name]
	if not func then
		return
	end
	return func(obj, ...)
end

RETURN()

local Map
if World.isClient then
    Map = World.MapClient
else
    Map = World.MapServer
    function Map:Destroy()
        if self.id == World.CurWorld.defaultMap.id then
            Lib.logWarning("DefaultMap cannot be Destroy !")
            return
        end
        self:close()
    end
end

Map.IsValid = Map.isValid

function Map:RayCheck(start, direction, len)
    local physics = self:getPhysicsWorld()
    local res = physics:raycast(start, direction, len)
    return res.targetType ~= 0
end

function Map:BoxCheck(center, extend, rotation)
    local physics = self:getPhysicsWorld()
    local res = physics:overlapShape({ type = "Box", extent = extend }, center, Quaternion.fromEulerAngleVector(rotation))
    return #res > 0
end

function Map:SphereCheck(center, radius)
    local physics = self:getPhysicsWorld()
    local res = physics:overlapShape({ type = "Sphere", radius = radius }, center, Quaternion.fromEulerAngle(0, 0, 0))
    return #res > 0
end

function Map:CylinderCheck(center, radius, height)
    local physics = self:getPhysicsWorld()
    local res = physics:overlapShape({ type = "Cylinder", radius = radius, height = height }, center, Quaternion.fromEulerAngle(0, 0, 0))
    return #res > 0
end

local function handleResult(res, origin)
    local result = {}
    for _, r in pairs(res) do
        local distance = (Lib.tov3(r.collidePos) - origin):len()
        result[#result + 1] = HitResult.new(r.target, r.collidePos, r.normalOnHitObject, distance)
    end
    table.sort(result, function(a, b)
        return a.Distance < b.Distance
    end)
    return result
end

function Map:RayCast(start, direction, len, isThrough)
    local physics = self:getPhysicsWorld()
    local res
    if isThrough == false then
        res = physics:raycast(start, direction, len)
        return res.targetType == 0 and {} or { HitResult.new(res.target, res.collidePos, res.normalOnHitObject, (Lib.tov3(res.collidePos) - start):len()) }
    else
        res = physics:raycastAll(start, direction, len)
        return handleResult(res, start)
    end
end

function Map:BoxCast(center, extend, rotation)
    local physics = self:getPhysicsWorld()
    local res = physics:overlapShape({ type = "Box", extent = extend }, center, Quaternion.fromEulerAngleVector(rotation))
    return handleResult(res, center)
end

function Map:SphereCast(center, radius)
    local physics = self:getPhysicsWorld()
    local res = physics:overlapShape({ type = "Sphere", radius = radius }, center, Quaternion.fromEulerAngle(0, 0, 0))
    return handleResult(res, center)
end

function Map:CylinderCast(center, radius, height)
    local physics = self:getPhysicsWorld()
    local res = physics:overlapShape({ type = "Cylinder", radius = radius, height = height }, center, Quaternion.fromEulerAngle(0, 0, 0))
    return handleResult(res, center)
end

local mapProxyTb = {
    Name = {
        get = function(map)
            return map.name
        end
    },
    Gravity = {
        get = function(map)
            return map:getPhysicsWorld():getGravity()
        end,
        set = function(map, gravity)
            map:getPhysicsWorld():setGravity(gravity)
        end
    },
    Root = {
        get = function(map)
            return map:getWorkSpace()
        end
    },
    ID = {
        get = function(map)
            return map.id
        end
    },
    IsStatic = {
        get = function(map)
            return map.static
        end
    }
}

function EventPoolMap:Init()
    self.__SignalID = nil
end

local function Emit(self, EventName, ...)
    if not EventName then
        return
    end
    local BindableEvent = self:GetEvent(EventName)
    if BindableEvent then
        BindableEvent:Emit(...)
    end
end

function EventPoolMap:EmitEvent(CppEventName, ...)
    self:Lock(CppEventName)
    local LuaEvent = Instance.ToLuaEvent(CppEventName)
    Emit(self, LuaEvent, ...)
    self:Unlock(CppEventName)
end

function BindableEventMap:Emit(...)
    local Owner = self:GetOwner()
    self.super.Emit(self, Owner, ...)
end

function BindableEventMap:Bind(Function)
    if not self:ExistBind() then
        local eventName = self:GetEventName()
        local Owner = self:GetOwner()
        local workSpace = Owner:getWorkSpace()
        self.__SignalID = workSpace:subscribeSceneEvent(Instance.ToCppEvent(eventName))
    end
    return self.super.Bind(self, Function)
end

function BindableEventMap:OnBindDestroy()
    if self:ExistBind() then
        return
    end
    local eventName = self:GetEventName()
    local Owner = self:GetOwner()
    local workSpace = Owner:getWorkSpace()
    workSpace:unsubscribeSceneEvent(Instance.ToCppEvent(eventName), self:GetSignalID())
end

local override = APIProxy.OverrideAPI({}, mapProxyTb)
Event:InterfaceForTable(override, Define.EVENT_SPACE.MAP, Define.EVENT_POOL.MAP)
APIProxy.Include(Map, override)
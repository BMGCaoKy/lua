---用于兼容Instance的EventPool子类
---代码中出现的self.super为EventPoolInstance
local Instance = Instance
local EventPool = EventPool
--local EventPoolInstance = EventPoolInstance
local EventPoolObject = EventPoolObject

function EventPoolObject:EmitEvent(EventName, ...)
    if Instance.IsCppEvent(EventName) then
        EventPoolObject.super.EmitEvent(self, EventName, ...)
    else
        EventPool.EmitEvent(self, EventName, ...)
    end
end

function EventPoolObject:OnBind(BindableEvent)
    if BindableEvent:IsConnect() then
        EventPoolObject.super.OnBind(self, BindableEvent)
    else
        EventPool.OnBind(self, BindableEvent)
    end
end

function EventPoolObject:OnBindDestroy(BindableEvent)
    if BindableEvent:IsConnect() then
        EventPoolObject.super.OnBindDestroy(self, BindableEvent)
    else
        EventPool.OnBindDestroy(self, BindableEvent)
    end
end

--common.object的加载时序过于靠前, 不便把这段代码放在object.lua中
local EventTable =
{
    "OnEntityClick",
    "OnClickEntity",
    "OnFallOffMap",
    "OnEntityDie",
    "OnKillEntity",
    "OnEntityHurt",
    "OnDoDamage",
    "OnEntityRebirth",
    "OnHandItemChanged",
    "OnUseItem",
    "OnItemAdded",
    "OnItemRemoved",
    "OnWearEquipment",
    "OnJoinTeam",
    "OnLeaveTeam",
    "OnEnterMap",
    "OnLeaveMap",
    "OnCollisionBegin",
    "OnCollisionEnd",
}
Event:RegisterEvents(EventTable, Define.EVENT_SPACE.OBJECT)

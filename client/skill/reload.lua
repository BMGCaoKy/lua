---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by work.
--- DateTime: 2019/4/9 11:04
---
local SkillBase = Skill.GetType("Base")
local Reload = Skill.GetType("Reload")
local reloadType = {}

Reload.reloadType = "Item"
Reload.castAction = "pistol_reload"

--重装容器(播放重装动作)
function Reload:reload(packet, from)
    if self.enableCdMask and self.cdTime > 0 then
        from:setCD(self.cdKey, self.reloadTime or 20, self)
    end
    packet.addCapacity = packet.addCapacity or 0
    from:data("reload").reloadTimer = from:timer(self.reloadTime or 20, self.finishReload, self, packet, from)
end

--尝试判断重装条件
function Reload:tryReload(packet, from)
    local currentCapacity, containerCfg = self:getContainerVar(from)
    if not currentCapacity then
        return false
    end
    if currentCapacity >= containerCfg.maxCapacity then
        return false
    end
    packet.addCapacity = containerCfg.maxCapacity - currentCapacity
    local type = containerCfg.reloadType or self.reloadType
    local func = assert(reloadType[type], type)
    if not func(self, packet, from) then
        return false
    end
    return true
end

--完成重装容量
function Reload:finishReload(packet, from)
    self:cancel(packet, from)
    SkillBase.cast(self, packet, from)
end

--取消重装（目前只用于重装容量�
function Reload:cancel(packet, from)
    local containerData = from:data("reload")
    if containerData.reloadTimer then
        containerData.reloadTimer()
        containerData.reloadTimer = nil
    end
end

function Reload:canCast(packet, from)
    if self.enableCdMask and self.cdTime > 0 and packet.method and packet.method == "Cancel" then
        from:setCD(self.cdKey, 0, self)
    end
    if not SkillBase.canCast(self, packet, from) then
        return false
    end
    local method = packet.method
    if method == "Cancel" then
        return true
    end
    if from:data("reload").reloadTimer then
        return false
    end
    if not self:tryReload(packet, from) then
        return false
    end
    if not SkillBase.canCast(self, packet, from) then
        return false
    end
    return true
end

function Reload:cast(packet, from)
    if not (from and from:isControl()) then
        return
    end
    local method = packet.method
    Lib.emitEvent(Event.EVENT_SHOW_RELOAD_PROGRESS, {cfg = self, method = method})
    if method == "Cancel" then
        self:cancel(packet, from)
    else
        self:reload(packet, from)
    end
end

function Reload:singleCast(packet, from)
    SkillBase.singleCast(self, packet, from)
end

function Reload:showIcon(show, index)
    if not show then
        Skill.Cast(self.fullName, { method = "Cancel" })
    end
    SkillBase.showIcon(self, show, index)
end

function Reload:preCast(packet, from)
    local method = packet.method
    if method == "Cancel" then
        SkillBase.stop(self, packet, from)
        return
    end
    Reload.castActionTime = self.reloadTime or 20
    SkillBase.preCast(self, packet, from)
end

function reloadType:Item(packet, from)
    local _, containerCfg = self:getContainerVar(from)
    local cash = from:tray():find_item_count(containerCfg.reloadName or self.reloadName, containerCfg.reloadBlock or self.reloadBlock)
    if cash == 0 then
        return false
    end
    return true
end

function reloadType:Custom(packet, from)
    return true
end
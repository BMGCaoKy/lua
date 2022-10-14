local setting = require "common.setting"

local Targets = T(Player, "Targets")

local TargetBase = T(Targets, "Base")
function TargetBase:init(tar)
	tar.process = 0
end
function TargetBase:add(tar, ...)
	tar.process = tar.process + 1
	return true
end
function TargetBase:load(tar, data)
	tar.process = data
end
function TargetBase:save(tar)
	return tar.process
end
function TargetBase:close(tar, ...)
end

local function CreateTargetClass(typ)
	local tb = Targets[typ]
	if not tb then
		tb = {}
		Targets[typ] = tb
	end
	for k, v in pairs(TargetBase) do
		tb[k] = v
	end
	return tb
end

function Player:initTarget(tt)
	local tar = {
		tt = tt,
		tc = Targets[tt.type] or TargetBase,
	}
	tar.tc.init(self, tar)
	if tar.process<tt.count then
		local tl = T(self:data("targetList"), tt.type)
		tar.index = #tl + 1
		tl[tar.index] = tar
	end
	return tar
end

function Player:loadTarget(tt, data)
	local tar = {
		tt = tt,
		tc = Targets[tt.type] or TargetBase,
	}
	tar.tc.load(self, tar, data or 0)
	assert(tar.process, tt.task.fullName)
	if tar.process<tt.count then
		local tl = T(self:data("targetList"), tt.type)
		tar.index = #tl + 1
		tl[tar.index] = tar
	end
	return tar
end

function Player:addTarget(typ, ...)
	local tl = self:data("targetList")[typ]
	if not tl then
		return
	end
	for _, tar in pairs(tl) do
		if tar.tc.add(self, tar, ...) then
			if tar.process>=tar.tt.count then	-- 目标已达成
				tl[tar.index] = nil
				tar.index = nil
			end
			self:syncTask(tar.tt.task)
		end
	end
end


local TargetLevel = CreateTargetClass("Level")
function TargetLevel:init(tar)
	tar.process = self:getValue("level")
end
function TargetLevel:add(tar, level)
	tar.process = level
	return true
end


local TargetKillNpc = CreateTargetClass("KillNpc")
function TargetKillNpc:add(tar, cfgName)
	if tar.tt.cfgName and tar.tt.cfgName~=cfgName then
		return false
	end
	tar.process = tar.process + 1
	return true
end

local TargetFindRegion = CreateTargetClass("FindRegion")
function TargetFindRegion:add(tar, cfgName)
	if tar.tt.cfgName and tar.tt.cfgName~=cfgName then
		return false
	end
	tar.process = tar.process + 1
	return true
end

local TargetGatherItems = CreateTargetClass("GatherItems")
function TargetGatherItems:add(tar, cfgName, count)
    local typ = cfgName
    if type(typ)== "number" then
        local name = setting:id2name("block", typ)
        if not name then
            return false
        end
        typ = name
    end
	if tar.tt.cfgName and tar.tt.cfgName ~= typ then
		return false
	end
	tar.process = tar.process + count
	return true
end

local TargetObject = CreateTargetClass("FindObject")
function TargetObject:add(tar, cfgName)
	if tar.tt.cfgName and tar.tt.cfgName~=cfgName then
		return false
	end
	tar.process = tar.process + 1
	return true
end

local TargetInteraction = CreateTargetClass("Interaction")
function TargetInteraction:add(tar, cfgName)
	if tar.tt.cfgName and tar.tt.cfgName~=cfgName then
		return false
	end
	tar.process = tar.process + 1
	return true
end
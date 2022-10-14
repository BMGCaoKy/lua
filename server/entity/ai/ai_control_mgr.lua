---@class ai_control_mgr
local ai_control_mgr = L("ai_control_mgr", {})
local Event = L("ai_control_event", {})
local M = ai_control_mgr

local CurWorld = World.CurWorld

function M:init()
    self.groupControl = {} -- groupID to control
	self.aiGroups = {}
end

function M:getAIControl(objID)
	local entity = CurWorld:getEntity(objID)
	return entity and entity:getAIControl()
end

function M:aiGroupAddObj(groupID, objID)
	local groupObjs = self.aiGroups[groupID]
	if not groupObjs then
		groupObjs = {}
		self.aiGroups[groupID] = groupObjs
	end
	groupObjs[objID] = true
end

function M:aiGroupDelObj(groupID, objID)
	local groupObjs = self.aiGroups[groupID] or {}
	groupObjs[objID] = nil
end

function M:getAIGroup(groupID)
    return self.aiGroups[groupID]
end

function M:startAI(entity)
    entity:enableAIControl(true)
    local control = entity:getAIControl()
    control:start()
    local groupID = control:getAiGroup()
	if groupID then
		self:aiGroupAddObj(groupID, entity.objID)
	end
end

function M:stopAI(entity)
    local control = entity:getAIControl()
	if control then
		local groupID = control:getAiGroup()
		if groupID then
			self:aiGroupDelObj(groupID, entity.objID)
		end
		control:stop()
	end
    -- 设置false会清除AI参数 entity:enableAIControl(false)
end

function M:continue(control)
    local entity = control:getEntity()
    control:continue()
end

function M:pause(control)
    local entity = control:getEntity()
    control:pause()
    control:setGroupStopFlag(false)
end

function M:changeAiGroupStatus(changeControl, isRunning)
    local groupID = changeControl:getAiGroup()
	if not groupID then
		return true
	end
	local aiGroup = self:getAIGroup(groupID) or {}
	if isRunning then
		for objID in pairs(aiGroup) do
			local control = self:getAIControl(objID)
			if control and not control:isActive() and changeControl:getID() ~= control:getID() then
				control:setActiveStatus(isRunning)
			end
		end
		return true
	else
		local ret = true
		changeControl:setGroupStopFlag(true)
		for objID in pairs(aiGroup) do
			local control = self:getAIControl(objID)
			if control and not control:getGroupStopFlag() then
				ret = false
				goto continue
			end
		end
		for objID in pairs(aiGroup) do
			local control = self:getAIControl(objID)
			if control then
				self:pause(control)
			end
		end
		::continue::
		return ret
	end
end

function Event.ai_status_change(self, control, isRunning)
    local isCanChange = self:changeAiGroupStatus(control, isRunning)
	if isRunning and isCanChange then
		self:continue(control)
	elseif isCanChange then
		self:pause(control)
	end	
end

function M:controlEventHandle(eventName, ...)
    local func = Event[eventName]
    if func then
        func(self, ...)
    end
end

M:init()

RETURN(M)

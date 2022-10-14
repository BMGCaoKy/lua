
local M = L("M", {})

local CurGuide = L("CurGuide")

-- 不同类型指引的定义
local GuideType = T(M, "GuideType")
local Base = T(GuideType, "Base")
Base.__index = Base

-- 指引开始执行
function Base:start()
end
-- 指引执行中，返回true表示执行完成
function Base:tick()
	return false
end
-- 指引执行完毕（释放资源）
function Base:stop()
end

local function GetType(typ)
	local tb = GuideType[typ]
	if not tb then
		tb = {}
		tb.__index = tb
		GuideType[typ] = setmetatable(tb, Base)
	end
	return tb
end

local None = GetType("None")
function None:tick()
	return true
end

local ButtonTip = GetType("ButtonTip")
function ButtonTip:tick()
	if self.finish then
		return true
	end
	for i = 1, 99 do
		local path = self.cfg["param"..i]
		local uiEventCfg = path
		if not path or path=="" then
			break
		end
		local p1, p2, _ = string.match(path, "^([^/@]*)/?([^@]*)@?(.*)$")
		path = p1.."/"..p2

		local node = UI:findChild(path, tonumber(self.cfg["index" .. i]))
		if node then
			local win_name, _, ename = string.match(uiEventCfg, "^([^/@]*)/?([^@]*)@?(.*)$")
			if #ename == 0 then
				ename = UIEvent.EventWindowTouchDown
			end
			local window = UI:getWnd(win_name)
			if window then
				UI:getWnd("guide_mask"):root():SetLevel(window:root():GetLevel())
			end
			local judgeTouchable
			if self.cfg["judgeTouchable"..i] then
				judgeTouchable = self.cfg["judgeTouchable"..i]:lower()=="true"
			end
			if node~=self.lastNode and (not judgeTouchable or node:IsTouchable()) then
				local canFinish = self.autoNext and i==1
				local text = self.cfg["text"..i] ~= "" and self.cfg["text"..i] or self.cfg.text
				local dir = self.cfg["dir"..i] ~= "" and self.cfg["dir"..i] or nil
				local radius = self.cfg["radius"..i] ~= "" and self.cfg["radius"..i]
				local showTipFrame = self.cfg["showTipFrame"..i] ~= "" and self.cfg["showTipFrame"..i] or true
				local clickEffect = self.cfg["clickEffect"..i] ~= "" and self.cfg["clickEffect"..i] or ""
				local needForce = ((self.cfg["needForce"..i] ~= "" and self.cfg["needForce"..i] == "TRUE") and true) or
						((self.cfg["needForce"..i] ~= "" and self.cfg["needForce"..i] == "FALSE") and false) or false
				local clickEffectPosX = self.cfg["clickEffectPosXOffset"..i] ~= "" and self.cfg["clickEffectPosXOffset"..i] or 0
				local clickEffectPosY = self.cfg["clickEffectPosYOffset"..i] ~= "" and self.cfg["clickEffectPosYOffset"..i] or 0
				local needForceCancelDragAction = ((self.cfg["needForceCancelDragAction"..i] ~= "" and self.cfg["needForceCancelDragAction"..i] == "TRUE") and true) or
						((self.cfg["needForceCancelDragAction"..i] ~= "" and self.cfg["needForceCancelDragAction"..i] == "FALSE") and false) or false
				local keepMask = self.cfg["keepMask" .. i] == "TRUE"
				if needForceCancelDragAction then
					UI:getWnd("actionControl"):onDragTouchUp()
				end
				local guidePacket = {
					target = node,
					text = text,
					dir = tonumber(dir),
					radius = radius,
					curNode = self.index + i,
					showTipFrame = showTipFrame,
					clickEffect = clickEffect,
					needForce = needForce,
					clickEffectPosX = tonumber(clickEffectPosX),
					clickEffectPosY = tonumber(clickEffectPosY),
					keepMask = keepMask,
				}
				if not World.CurWorld.isEditor then
					Lib.emitEvent(Event.EVENT_SHOW_TIP, guidePacket, function ()
						if canFinish then
							if Me.guildingId then
								Me.guildingId = nil
								-- print("=================canFinish====================",Me.guildingId)
							end
							if not keepMask then
								UI:closeWnd("guide_mask")
							end
							self.finish = true
							if self.cfg.triggerName then
								Me:sendTrigger(Me, self.cfg.triggerName, Me, nil, { saveKey = self.cfg.saveKey })
								if self.cfg.triggerName =="FINISH_NEW_COMER_GUIDE_32" then--temp plan by zhuyayi
									Lib.emitEvent("TEMP_RECOVER_MOVE")
								end
							end
						end
						self.lastNode = nil
						Lib.emitEvent(Event.EVENT_HIDE_TIP, not keepMask)
					end, ename)
				else
					Lib.emitEvent(Event.EVENT_EDITOR_SHOW_TIP, node, text, tonumber(dir), radius, i, function ()
						if canFinish then
							if not keepMask then
								UI:closeWnd("guide_mask")
							end
							self.finish = true
							if self.cfg.triggerName then
								Me:sendTrigger(Me, self.cfg.triggerName, Me, nil, { saveKey = self.cfg.saveKey })
							end
						end
						self.lastNode = nil
						-- Lib.emitEvent(Event.EVENT_EDITOR_HIDE_TIP)
					end, ename)
				end
				self.lastNode = node
				if not Me.guildingId or Me.guildingId ~= node:getId() then
					Me.guildingId = node:getId()
					-- print("=================start====================",Me.guildingId)
				end
			end
			return false
		end
	end
	if self.lastNode then
		self.lastNode = nil
        local event = World.CurWorld.isEditor and Event.EVENT_EDITOR_HIDE_TIP or Event.EVENT_HIDE_TIP
		Lib.emitEvent(event, true)
	end
	return false
end

function ButtonTip:start()
    Lib.subscribeEvent(Event.EVENT_NOVICE_GUIDE, function(indexType, isFinish)
        if indexType == 4 then
            self.finish = true
			if isFinish then
				Lib.emitEvent(Event.EVENT_EDITOR_HIDE_TIP)
			end
        end
    end)
end

function ButtonTip:stop()
	if self.lastNode then
		self.lastNode = nil
        local event = World.CurWorld.isEditor and Event.EVENT_EDITOR_HIDE_TIP or Event.EVENT_HIDE_TIP
		--Lib.emitEvent(event)
	end
end

local ShowTip = GetType("ShowTip")
function ShowTip:start()
	Client.ShowTip(tonumber(self.cfg.param1), self.cfg.text,tonumber(self.cfg.showTimeLength))
	self.startTime = World.Now()
end
function ShowTip:tick()
	return World.Now() - self.startTime > 20 * 3
end

local ShowBox = GetType("ShowBox")
function ShowBox:start()
end
function ShowBox:tick()
	return false
end
function ShowBox:stop()
end

local ShowEffect = GetType("ShowEffect")
local guideDone = {}
local cancelNext = {}
function ShowEffect:start()
	local path = self.cfg.param1
	if not path or path == "" then
		return
	end
	local node = UI:findChild(path)
	if node then
		local effectWidget = UI:findChild(self.cfg.effectWidgetPath or "") or node
		local winName, _, ename = string.match(path, "^([^/@]*)/?([^@]*)@?(.*)$")
		if #ename == 0 then
			ename = UIEvent.EventWindowTouchDown
		end

--		if not Me.guildingId or Me.guildingId ~= node:getId() then
--			Me.guildingId = node:getId()
--			print("=================start====================",Me.guildingId)
--		end

		local radius = self.cfg.radius1 or ""
		local effect = self.cfg.effect1 or ""
		if radius ~= "" or effect ~= "" then
			self.effectCb = function()
				self.startTime = nil
				effectWidget:UnprepareEffect()
				--UI:closeWnd("guide_mask")
			end
			self.cb = function()
				if guideDone[node] then
					return
				end
				guideDone[node] = true
				self.effectCb()
				if not cancelNext[winName] and self.cfg.triggerName then
					Me:sendTrigger(Me, self.cfg.triggerName, Me, nil, { saveKey = self.cfg.saveKey })
				end
			end
			node:subscribe(ename, self.cb)
			effectWidget:SetEffectName(effect)
			if self.cfg.showTimeLength ~= "" and tonumber(self.cfg.showTimeLength) > 0 then
				self.startTime = World.Now()
			end
			if radius ~= "" and tonumber(radius) > 0 then
				local area = node:GetRenderArea()
				local size = node:GetPixelSize()
				local window = UI:openWnd("guide_mask")
				window:updateMask(area[3] - size.x / 2, area[4] - size.y / 2, radius)
			end
		end

		Lib.subscribeEvent(Event.EVENT_UPDATE_GUIDE_DATA, function(win)
			cancelNext[win] = true
			if self.cb then
				self.cb()
			end
		end)
	end
end
function ShowEffect:tick()
	if not self.startTime then
		return false
	end
	return World.Now() - self.startTime > tonumber(self.cfg.showTimeLength) * 20
end
function ShowEffect:stop()
	local autoEx = self.cfg.autoExecute or ""
	if autoEx:lower() == "true" and self.cb then
		self.cb()
		return
	end
	if self.effectCb then
		self.effectCb()
	end
end

function M.GotoStep(index)
	assert(not CurGuide)
	local cfg = World.guideCfg[index]
	if not cfg then
		return
	end
	if cfg.type=="" then
		cfg.type = "None"
	end
	local tb = assert(GuideType[cfg.type], cfg.type)
	CurGuide = {
		cfg = cfg,
		index = index,
		autoNext = cfg.autoNext:lower()=="true",
	}
	setmetatable(CurGuide, tb)
	CurGuide:start()
end

function M.SetStep(step)
	M.Close()
	for index, cfg in ipairs(World.guideCfg) do
		if not step or cfg.saveKey==step then
			M.GotoStep(index)
			return
		end
	end
	print("guide no step:", step)
end

function M.Tick()
	if not CurGuide or not CurGuide:tick() then
		return
	end
	local lastGuide = CurGuide
	M.Close()
	if not lastGuide.autoNext then
		return
	end
	M.GotoStep(lastGuide.index + 1)
	if CurGuide and CurGuide.cfg.saveKey~="" then
		local packet = {
			pid = "GuideStep",
			step = CurGuide.cfg.saveKey,
		}
		Player.CurPlayer:sendPacket(packet)
	end
end

function M.Close()
	if CurGuide then
		CurGuide:stop()
		CurGuide = nil
	end
end

function M.CurGuide()
	return CurGuide
end


RETURN(M)

local RECEIVER_ID = "{C4D8BAF6-3B94-4FBF-86B3-829206AB8398}"
local MATERIAL_ID = "{CA5A349C-FCE8-4DEF-9579-02705EB6BBFD}"

local UserData = {}
local ShaderTimer = {}

---@class GUIFont
---@field GetTextExtent fun(self : GUIFont, text : string, scale : number) : number
---@field GetFontHeight fun(self : GUIFont) : number
---@field GetLineExtraSpace fun(self : GUIFont) : number
---@field GetLineSpacing fun(self : GUIFont) : number
---@field GetStringWidth fun(self : GUIFont, text : string) : number
---@field GetTextHigh fun(self : GUIFont, text : string, scale : number) : number
---@field SplitStringToMultiLine fun(self : GUIFont, width : number, color : table, text : string, outList : table, outHighList : table) : table

---@type Vector2
---@field x number
---@field y number

---@type GUIWindow
local GUIWindow = GUIWindow

---@class WightRootWindow : GUIWindow
local WightRootWindow = GUIWindow

function GUIWindow:initData()
	local id = self:getId()
	UserData[id] = {
		[RECEIVER_ID] = nil,
		[MATERIAL_ID] = {}
	}
	return UserData[id]
end

function GUIWindow:onDestroy()
	local id = self:getId()
	self:invoke("destroy")
	UserData[id] = nil
end

function GUIWindow:data(key)
	local id = self:getId()
    local data = UserData[id] or self:initData()
	return data[key]
end

function GUIWindow:setData(key, val)
	local id = self:getId()
	local data = UserData[id] or self:initData()
	data[key] = val
end

function GUIWindow:invoke(name, ...)
	local receiver = self:data(RECEIVER_ID)
	if receiver and receiver.onInvoke then
		return receiver:onInvoke(name, ...)
	end
end

function GUIWindow:connect(receiver)
	self:setData(RECEIVER_ID, assert(receiver))
end

function GUIWindow:receiver()
	return self:data(RECEIVER_ID)
end

function GUIWindow:setEnableLongTouchRecursivly(enable)
	local childCount = self:GetChildCount()
	if childCount == 0 then
		self:setEnableLongTouch(enable)
		return
	end
	for i = 1, childCount do
		---@type CGUIWindow
		local child = self:GetChildByIndex(i - 1)
		child:setEnableLongTouch(enable)
	end
	self:setEnableLongTouch(enable)
end

function GUIWindow:SetEnabledRecursivly(enable)
	local childCount = self:GetChildCount()
	if childCount == 0 then
		self:SetEnabled(enable)
		return
	end
	for i = 1, childCount do
		local child = self:GetChildByIndex(i - 1)
		child:SetEnabledRecursivly(enable)
	end
	self:SetEnabled(enable)
end

--not recursivly
function GUIWindow:SetEnabled(enable)
	self:setEnabled(enable)

	if enable then
		self:setProgram("NORMAL")
	else
		self:setProgram("GRAY")
	end
end

function GUIWindow:setProgramRecursivly(name)
	local childCount = self:GetChildCount()
    if childCount == 0 then
        self:setProgram(name)
        return
    end
    for i = 1, childCount do
        local child = self:GetChildByIndex(i - 1)
        child:setProgramRecursivly(name)
    end
    self:setProgram(name)
end

function GUIWindow:setProgram(name)
	local program = require("shader")[name]
	if not program then
		self:setProgram("NORMAL")
		return
	end

	-- 设置 program
	self:bindProgram(name)

	-- 设置 uniform
	local index_table = {}
	local meta = { __index = index_table }

	for key, val in ipairs(program.uniform or {}) do
		assert(val.name ~= "matWVP" and val.name ~= "texSampler")

		if val.type == "float" then
			self:insertShaderParam1f(val.name, val.value)
		elseif val.type == "float4" then
			self:insertShaderParam4f(val.name, {x = val.value[1] or 0.0, y = val.value[2] or 0.0, z = val.value[3] or 0.0, w = val.value[4] or 1.0})
		else
			assert(false, string.format("insert uniform type is error: %s", val.type))
		end

		index_table[val.name] = function(_, ...)
			if val.type == "float" then
				self:modifyShaderParam1f(val.name, ...)
			elseif val.type == "float4" then
				local x, y, z, w = ...
				self:modifyShaderParam4f(val.name, {x = x or 0.0, y = y or 0.0, z = z or 0.0, w = w or 1.0})
			else
				assert(false, string.format("modify uniform type is error: %s", val.type))
			end
		end
	end

	setmetatable(self:material(), meta)
end

function GUIWindow:material()
	return self:data(MATERIAL_ID)
end

local function autoRoundingPercent(percent)
	if percent < 0 then
		percent = 0
	elseif percent > 1 then
		percent = 1
	end
	return percent
end

local function fetchImg(png,program)
	---@type GUIStaticImage
	local img = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "")
	img:SetImage(png)
	img:setProgram(program)
	img:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
	img:SetAlwaysOnTop(true)
	return img
end

local maskName = "{0D2D61DC-8DF6-47A0-BA88-892C66979CFB}"
function GUIWindow:setMask(percent,iRadius,iColorAlpha)
	percent = percent or 1
	percent = autoRoundingPercent(percent)

	local img = self:child(maskName)
	if not img then
		img = fetchImg("empty.png","CLOCK")
		self:AddChildWindow(img, maskName)
	end

	local size = img:GetPixelSize()
	img:material():iSize(size.x, size.y)
	img:material():iProgress(1 - percent)
	if iRadius then
		img:material():iRadius(size.x * iRadius) --
	end
	if iColorAlpha then
		img:material():iColorAlpha(iColorAlpha) --
	end
	return img
end

function GUIWindow:setGuideMask(posx, posy, radius)
	local img = self:child(maskName)
	if not img then
		img = fetchImg("empty.png","GUIDEMASK")
		img:SetTouchable(false)
		self:AddChildWindow(img, maskName)
	end

	local size = img:GetPixelSize()
	img:material():iSize(size.x, size.y)
	img:material():iProgress(1)
	img:material():iPos(posx, posy, 0, 0)
	img:material():iRadius(radius)
end

function GUIWindow:setRectangleMask(area)
	local img = self:child(maskName)
	if not img then
		img = fetchImg("empty.png","RECTANGLEMASK")
		img:SetTouchable(false)
		self:AddChildWindow(img, maskName)
	end

	local size = img:GetPixelSize()
	img:material():iSize(size.x, size.y)
	img:material():iTopleft(area[1], area[2], 0, 0)
	img:material():iBottomright(area[3], area[4], 0, 0)
end

function GUIWindow:setCircleCut(radius)
	self:setProgram("CIRCLECUT")
	local size = self:GetPixelSize()
	self:material():iSize(size.x, size.y)
	self:material():iRadius(radius)
end

function GUIWindow:setSectorBar(progress, distanceX, distanceY)
	self:setProgram("SECTOR")
	local size = self:GetPixelSize()
	self:material():iDistancex(distanceX)
	self:material():iDistancey(distanceY)
	self:material():iSize(size.x, size.y)
	self:material():iProgress(progress)
end

function GUIWindow:setSectorBar2(progress, distanceX, distanceY)
	self:setProgram("SECTOR2")
	local size = self:GetPixelSize()
	self:material():iDistancex(distanceX)
	self:material():iDistancey(distanceY)
	self:material():iSize(size.x, size.y)
	self:material():iProgress(progress)
end

--renderSpeed: 渲染前进速度
function GUIWindow:setRing(pressTime, renderSpeed, inRadius, outRadius)
    assert(pressTime > 0, "pressTime must greater then 0")
    assert(renderSpeed > 0, "renderSpeed must greater then 0")
    assert(pressTime >= renderSpeed, "pressTime must greater or equal to renderSpeed")

    local img = self
	--img:SetImage("empty.png")
    img:setProgram("RING")
    local timer = ShaderTimer.RING;
    local function finish()
        img:SetVisible(false)
        if timer then
            timer()
            timer = nil
            ShaderTimer.RING = nil
        end
    end
    finish()
    img:SetVisible(true)

    local times = 0
    local headProgress = 0
    local tailProgress = 0
    local headUpdate = (1 + renderSpeed / pressTime) / pressTime
    local tailUpdate = (renderSpeed / pressTime) / pressTime
    timer = World.Timer(1, function()
        headProgress = headProgress + headUpdate
        tailProgress = tailProgress + tailUpdate
        local size = self:GetPixelSize()
        inRadius = inRadius or 10
        outRadius = outRadius or 20
        img:material():iInRadius(inRadius)
        img:material():iOutRadius(outRadius)
        img:material():iSize(size.x, size.y)
        img:material():iHeadProgress(headProgress)
        img:material():iTailProgress(tailProgress)
        times = times + 1
        if times > pressTime then finish() end
        return times <= pressTime
    end)
	ShaderTimer.RING = timer
	return finish
end

--renderSpeed: 渲染前进速度
function GUIWindow:setRingWithVisableImg(pressTime, renderSpeed, inRadius, outRadius)
	assert(pressTime > 0, "pressTime must greater then 0")
	assert(renderSpeed > 0, "renderSpeed must greater then 0")
	assert(pressTime >= renderSpeed, "pressTime must greater or equal to renderSpeed")

	local img = self
	img:setProgram("RING2")
	local timer = ShaderTimer.RING2;
	local function finish()
		img:SetVisible(false)
		if timer then
			timer()
			timer = nil
			ShaderTimer.RING2 = nil
		end
	end
	finish()
	img:SetVisible(true)

	local times = 0
	local headProgress = 0
	local tailProgress = 0
	local headUpdate = (1 + renderSpeed / pressTime) / pressTime
	local tailUpdate = (renderSpeed / pressTime) / pressTime
	timer = World.Timer(1, function()
		headProgress = headProgress + headUpdate
		tailProgress = tailProgress + tailUpdate
		local size = self:GetPixelSize()
		inRadius = inRadius or 10
		outRadius = outRadius or 20
		img:material():iInRadius(inRadius)
		img:material():iOutRadius(outRadius)
		img:material():iSize(size.x, size.y)
		img:material():iHeadProgress(headProgress)
		img:material():iTailProgress(tailProgress)
		times = times + 1
		if times > pressTime then finish() end
		return times <= pressTime
	end)
	ShaderTimer.RING2 = timer
	return finish
end

function GUIWindow:setTextAutolinefeed(text, maxLine)
	local function transform(wnd,text,Width)
		local result = ""
		local curText = ""
		local curWidth = 0
		local tbl = Lib.splitString(text, " ")
		local curLine = maxLine and 1
		for k, str in ipairs(tbl) do
			curText = curText .. str .. " "
			curWidth = wnd:GetFont():GetTextExtent(curText,1.0)
			if k ~= 1 and curWidth > Width then
				curText = str .. " "
				if curLine then
					curLine = curLine + 1
					if curLine >= maxLine and k ~= #tbl then
						result = result .. "\n" .. str .. "..."
						break
					end
				end
				result = result .. "\n" .. str .. " "
			else
				result = result .. str .. " "
			end
		end
		return result
	end
	local area = self:GetRenderArea()
	local width = area[3] - area[1]
	if World.LangPrefix ~= "zh" then
		text = transform(self,text,width)
	end
	self:SetText(text)
end

do
	local subscriber = {}
	function GUIWindow:subscribe(event, cb, ...)
		local eid = UIMgr:event_id(self, event)
		local cancel = Lib.subscribeEvent(eid, cb, ...)
		local wid = self:getId()

		subscriber[wid] = subscriber[wid] or {}
		subscriber[wid][event] = subscriber[wid][event] or {}
		table.insert(subscriber[wid][event], cancel)

		return cancel
	end

	function GUIWindow:lightSubscribe(stack, event, cb, ...)
		assert(stack, " GUIWindow:lightSubscribe need stack!")
		local eid = UIMgr:event_id(self, event)
		local cancel = Lib.lightSubscribeEvent(stack, eid, cb, ...)
		local wid = self:getId()

		subscriber[wid] = subscriber[wid] or {}
		subscriber[wid][event] = subscriber[wid][event] or {}
		table.insert(subscriber[wid][event], cancel)

		return cancel
	end

	function GUIWindow:unsubscribe(event)
		local wid = self:getId()
		local events = subscriber[wid]
		if events then
			if not event then
				for _, cancels in pairs(events or {}) do
					for _, cancel in ipairs(cancels) do
						cancel()
					end
				end
				subscriber[wid] = {}
			else
				for _, cancel in pairs(events[event] or {}) do
					cancel()
				end
				events[event] = {}
			end
		end
	end

end

---获取控件当前文本高度
function GUIWindow:GetTextHeight()
	local text = self:GetText()
	local font = self:GetFont()
	local height = font:GetFontHeight(text, 1)
	local outList = font:SplitStringToMultiLine(self:GetPixelSize().x, { 1, 1, 1, 1 }, text, {}, {})
	return height * #outList
end

---获取控件当前文本宽度
function GUIWindow:GetTextWidth()
	local text = self:GetText()
	local font = self:GetFont()
	return font:GetTextExtent(text, 1)
end

---设置皮肤信息到GUIActorWindow上
---@param actorName string eg: boy.actor
---@param skins table entity:data("skins") or http data
function GUIWindow:SetActorInfo(actorName, skins)
	self:SetActor1(actorName, "idle")
	skins = EntityClient.processSkin(actorName, skins)
	for master, slave in pairs(skins) do
		self:UseBodyPart(master, slave)
	end
end

---设置玩家皮肤信息到GUIActorWindow上
---@param player EntityClient 玩家对象
function GUIWindow:SetPlayerActor(player)
	local actorName = player:getActorName()
	local skins = player:data("skins")
	self:SetActorInfo(actorName, skins)
end

---设置打开时长时间信息到GUIWindow上
---@param start boolean false/true
function GUIWindow:setTimerGoing(start)
	local openTime = self:data("engine_open_time")
	if start then
		self:setData("engine_open_time", os.time())
	elseif openTime then
		local oldTimeLength = self:data("engine_open_time_length") or 0
		self:setData("engine_open_time_length", oldTimeLength + os.time() - openTime)
		self:setData("engine_open_time", nil)
	end
end

function GUIWindow:getTotalOpenTime()
	local totalTime = self:data("engine_open_time_length") or 0
	local openTime = self:data("engine_open_time")
	if openTime then
		totalTime = totalTime + os.time() - openTime
	end
	return totalTime
end

---@return widget_base
function WightRootWindow:get()
	return self:invoke("get")
end
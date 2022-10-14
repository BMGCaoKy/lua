local curAxis = L("curAxis")
local drag = L("drag")
local offPos = L("offPos", {x=0,y=0,z=0})
local touchDown = L("touchDown", false)
local allAxis = L("allAxis", {
	{1,0,0},
	{0,1,0},
	{0,0,1},
})

function M:init()
    WinBase.init(self, "EditorHelper.json")
	self.lines = {}
	for id = 1,3 do
		local line = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", string.format("EditorHelper_Line_%d", id))
		line:SetTouchable(false)
		self.lines[id] = line
		self._root:AddChildWindow(line)
	end
	World.Timer(1, self.tick, self)

	self._original = Me:getPosition()

    self:subscribe(self._root, UIEvent.EventWindowTouchDown, function()
			if not touchDown then
				Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_START, self._original, offPos)
				touchDown = true
			end
		end)
    self:subscribe(self._root, UIEvent.EventWindowTouchUp, function()
		if touchDown then
			Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_END, self._original, offPos)
			touchDown = false
		end
	end)

	self._btn_ok = assert(self:child("EditorHelper-ok"))
	self._btn_ok:SetVisible(false)
	self:subscribe(self._btn_ok, UIEvent.EventButtonClick, function()
		Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_CONFIRM, true)
	end)

	self._btn_cannel = assert(self:child("EditorHelper-cancel"))
	self._btn_cannel:SetVisible(false)
	self:subscribe(self._btn_cannel, UIEvent.EventButtonClick, function()
		Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_CONFIRM, false)
	end)

	self._need_confirm = false
end

function M:fixLine(id, sx, sy, ex, ey, width, color)
	local dx, dy = ex-sx, ey-sy
	local line = self.lines[id]
	local l = math.sqrt(dx*dx + dy*dy)
	line:SetArea({0,sx+(dx-l)/2}, {0,sy+(dy-width)/2}, {0,l}, {0,width})
	line:SetBackgroundColor(color)
	line:SetRotate(math.deg(math.atan(dy, dx)))
end

local function routePos(x, y, z)
	local r = math.rad(Me:getRotationYaw())
	local p1, p2 = math.sin(r), math.cos(r)
	x, z = x*p2 - z*p1, x*p1 + z*p2
	r = math.rad(Me:getRotationPitch())
	p1, p2 = math.sin(r), math.cos(r)
	z, y = z*p2 - y*p1, z*p1 + y*p2
	return x, y, z
end

local function screenPos(p1, p2, ...)
	if p2 then
		return screenPos(Lib.v3add(p1, p2), ...)
	end
	return GUISystem.instance:WorldPostionToScreen(p1)
end

function M:drawAxis()
	local pp = self._original
	local mp = Blockman.instance:getMousePos()
	if touchDown then
		if not drag then
			drag = {
				axis = curAxis,
				mx = mp.x,
				my = mp.y,
				off = offPos,
			}
			if curAxis then
				local ap0 = screenPos(offPos, pp)
				local ap1 = screenPos(offPos, pp, {x=curAxis[1], y=curAxis[2], z=curAxis[3]})
				local dx, dy = ap1.x-ap0.x, ap1.y-ap0.y
--				print(ap0.x, ap0.y, ap1.x, ap1.y)
				drag.adx, drag.ady = dx, dy
				drag.apl = math.sqrt(dx*dx + dy*dy)
			end
		elseif drag.axis then
			local dx, dy = mp.x-drag.mx, mp.y-drag.my
			local l = math.floor((dx*drag.adx+dy*drag.ady)/drag.apl/drag.apl)
			local lastOffPos = offPos
			offPos = Lib.v3add(drag.off, {x=drag.axis[1]*l, y=drag.axis[2]*l, z=drag.axis[3]*l})
			if (lastOffPos.x ~= offPos.x or lastOffPos.y ~= offPos.y or lastOffPos.z ~= offPos.z) then
				Lib.emitEvent(Event.EVENT_EDITOR_GIZMO_DRAG_MOVE, self._original, offPos, Lib.v3cut(offPos, lastOffPos))
			end

--			print(l, offPos.x, offPos.y, offPos.z)
		end
	else
		drag = nil
	end

	local pos = screenPos(offPos, pp)

	local axis = {}
	local LEN = 200
	for i, tb in ipairs(allAxis) do
		local x, y, z = table.unpack(tb)
		axis[i] = {
			axis = tb,
			pos = {routePos(x*LEN, y*LEN, z*LEN)},
			color = {x, y, z},
		}
	end
	table.sort(axis, function(a,b) return a.pos[3]>b.pos[3] end)

	curAxis = nil

	for i, tb in ipairs(axis) do
		local x, y, z = table.unpack(tb.pos)
		local dl = math.sqrt(x*x + y*y)
		local mx, my = mp.x-pos.x, mp.y-pos.y
		local l = (mx*x - my*y) / dl
		local h = math.abs(mx*y + my*x) / dl
		local color = tb.color
		if drag then
			color[4] = drag.axis == tb.axis and 1 or 0.6
		else
			if l>10 and l<dl and h<20 then
				color[4] = 1
				curAxis = tb.axis
			else
				color[4] = 0.6
			end
		end
		self:fixLine(i, pos.x, pos.y, pos.x+x, pos.y-y, 10, tb.color)
	end

	self._root:SetTouchable(curAxis~=nil or drag~=nil)
end

function M:onOpen()

end

function M:onClose()

end

function M:reset(pos, need_confirm)
	assert(pos.x)
	self._original = pos
	offPos = {x = 0, y = 0, z = 0}

	self._need_confirm = need_confirm
	if need_confirm then
		self._btn_ok:SetVisible(true)
		self._btn_cannel:SetVisible(true)
	else
		self._btn_ok:SetVisible(false)
		self._btn_cannel:SetVisible(false)
	end
end

function M:tick()
	self:drawAxis()
	return true
end

RETURN(M)

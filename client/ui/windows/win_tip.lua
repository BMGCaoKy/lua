local DIR_LEFT		= 1
local DIR_RIGHT		= 2
local DIR_TOP		= 3
local DIR_BOTTOM	= 4
local cur = nil
local step = nil
local oldTarget = nil

function M:init()
	WinBase.init(self, "Tip.json")
    --self:root():SetAlwaysOnTop(true)
	self:root():SetLevel(1)
	self._lb_desc = self:child("Tip-Desc")
	self._lb_frame = self:child("Tip-Frame")
	self.show_effect = self:child("Tip-show-effet")
	self._lb_dir = {
		[DIR_LEFT]		= self:child("Tip-Left"),
		[DIR_RIGHT]		= self:child("Tip-Right"),
		[DIR_TOP]		= self:child("Tip-Top"),
		[DIR_BOTTOM]	= self:child("Tip-Bottom")
	}

	self._cancel = nil
end

function M:clearCur()
    cur = nil
end

local offset = 16
local curGuide = nil
function M:adjust(target, dir, pos_x, pos_y, radius, curNode, showTipFrame, clickEffect, needForce, clickEffectPosX, clickEffectPosY, pw, ph, keepMask)
	if not target then
		return
	end
	-- 计算目标中点的屏幕空间偏移，根据偏移量来决定 tip 显示
	local sw, sh = GUISystem.instance:GetScreenWidth(), GUISystem.instance:GetScreenHeight()
	local sl, st, sr, sb = table.unpack(target:GetScreenRenderArea())
	local dx, dy = (sl + sr) / 2 - (sw / 2), (st + sb) / 2 - (sh / 2)

	local ll, lt, lr, lb = table.unpack(target:GetRenderArea())
	local w, h = self:root():GetPixelSize().x, self:root():GetPixelSize().y

	local posx, posy = (ll + lr) / 2 - (w / 2), (lt + lb) / 2 - (h / 2)	-- 中点和 target 一致
	local effectPosx, effectPosy = posx, posy
	if not dir then
	    if math.abs(dx) > math.abs(dy) then
	    	if dx > 0 then
	    		-- left
	    		dir = DIR_RIGHT
	    	else
	    		-- right
	    		dir = DIR_LEFT
	    	end
	    else
	    	if dy > 0 then
	    		-- top
	    		dir = DIR_BOTTOM
	    	else
	    		-- bottom
	    		dir = DIR_TOP
	    	end
	    end
    end

	if dir == DIR_RIGHT then
		posx = ll - w - offset
    elseif dir == DIR_LEFT then
        posx = lr  + offset
    elseif dir == DIR_BOTTOM then
        posy = lt - h - offset
    elseif dir == DIR_TOP then
        posy = lb + offset
    end


	for k, v in pairs(self._lb_dir) do
		if k == dir then
			v:SetVisible(true)
		else
			v:SetVisible(false)
		end
	end
    local targetWnd = target
    local area = targetWnd:GetRenderArea()
	if not curGuide then
		curGuide = curNode
		if pos_x and pos_y then
			local window = UI:openWnd("guide_mask")

			if not cur and not step then
				cur = curNode
				step = Me:getValue("guideStep")
				window:setEffect(effectPosx + (clickEffectPosX), effectPosy + (clickEffectPosY), clickEffect)
			end

			if cur ~= curNode or step ~= Me:getValue("guideStep") then
				cur = curNode
				step = Me:getValue("guideStep")
				window:setEffect(effectPosx + (clickEffectPosX), effectPosy + (clickEffectPosY), clickEffect)
			end

            window:child("Mask-guideMask"):setPierceArea(area)
            if radius then
			    window:updateMask(pos_x - pw, pos_y - ph, radius, needForce)
            else
				window:setMask(area, needForce, pos_x - pw, pos_y - ph, radius)
            end
		end
	elseif curGuide ~= curNode then
		curGuide = curNode
		if not keepMask then
			UI:closeWnd("guide_mask")
		end
	elseif curGuide == curNode then
		if pos_x and pos_y then
			local window = UI:openWnd("guide_mask")

			if not cur and not step then
				cur = curNode
				step = Me:getValue("guideStep")
				window:setEffect(effectPosx + (clickEffectPosX), effectPosy + (clickEffectPosY), clickEffect)
			end

			if cur ~= curNode or step ~= Me:getValue("guideStep") then
				cur = curNode
				step = Me:getValue("guideStep")
				window:setEffect(effectPosx + (clickEffectPosX), effectPosy + (clickEffectPosY), clickEffect)
			end

            window:child("Mask-guideMask"):setPierceArea(area)
			if radius then
			    window:updateMask(pos_x - pw, pos_y - ph, radius, needForce)
            else
				window:setMask(area, needForce, pos_x - pw, pos_y - ph, radius)
            end
		end
	end


	self:root():SetXPosition({0, posx})
	self:root():SetYPosition({0, posy})
	
	self:root():SetVisible(showTipFrame)
end

local function getWindowAbPos(window, width, height)
	local w,h = width or window:GetWidth()[1], height or window:GetHeight()[1]
	local parent = window:GetParent()
	if not parent then
		return w, h
	end
	w = (w == 0 and 1 or w)* (parent:GetWidth()[2] == 0 and 1 or parent:GetWidth()[2])
	h = (h == 0 and 1 or h) * (parent:GetHeight()[2] == 0 and 1 or parent:GetHeight()[2])
	return getWindowAbPos(parent, w, h)
end

function M:attach(guidePacket, cb, event)
	assert(event, tostring(event))
	self.reloadArg = table.pack(guidePacket.target, guidePacket.text, guidePacket.dir, guidePacket.radius, guidePacket.curNode, cb)
	if not guidePacket.target then
		return
	end

	self._lb_desc:SetText(Lang:toText(guidePacket.text))
	local height = self._lb_desc:GetHeight()
	height[2] = height[2] + 20
	self:root():SetHeight(height)


	if self._cancel then
		self._cancel()
		self._cancel = nil
	end

	if cb then
		self._cancel = guidePacket.target:subscribe(event, cb)
	end

	-- 获得 target 的 root
	local desktop = GUISystem.instance:GetRootWindow()

	local targetWnd = guidePacket.target
	local area = targetWnd:GetRenderArea()
	local size = targetWnd:GetPixelSize()
	self:adjust(guidePacket.target,guidePacket.dir, area[3], area[4], guidePacket.radius, guidePacket.curNode, guidePacket.showTipFrame,
			guidePacket.clickEffect, guidePacket.needForce, guidePacket.clickEffectPosX, guidePacket.clickEffectPosY, size.x/2, size.y/2,
			guidePacket.keepMask)

	repeat
		local parent = targetWnd:GetParent()
		if not parent then
			return
		end

		if parent:getId() == desktop:getId() then
			break
		end

		targetWnd = parent
	until(false)

	if not targetWnd then
		return
	end


--	local count = desktop:GetDrawlistCount()
--	self:root():ShowOnTop()	-- 先显示到最上
--	assert(self:root():getId() == desktop:GetChildByIndexInDrawlist(count - 1):getId())
--	if not radius then
--		for index = count - 2, 0, -1 do
--			local wnd = desktop:GetChildByIndexInDrawlist(index)
--			assert(wnd, index)

--			if wnd:getId() == targetWnd:getId() then
--				break
--			end

--			self:root():MoveBack()
--		end
--	end
end

function M:onReload(reloadArg)
	local target, text, dir, radius, curNode, cb = table.unpack(reloadArg or {}, 1, reloadArg and reloadArg.n)
	self:attach(target, text, dir, radius, curNode, cb)
end

return M

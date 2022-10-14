local DIR_LEFT		    = 1
local DIR_RIGHT		    = 2
local DIR_TOP		    = 3
local DIR_BOTTOM	    = 4
local temp_Posx = 0
local temp_TextLength = 0
local isWordWrap = false
local isTextExceed = false


function M:init()
	WinBase.init(self, "guideTip_edit.json")
    self:root():SetAlwaysOnTop(true)
    self:root():setBelongWhitelist(true)
	self:root():SetLevel(10)
	self._lb_desc = self:child("Tip-Desc")
	self._lb_frame = self:child("Tip-Frame")
    self._lb_icon1 = self:child("Tip-Frame-Icon1")
    self._lb_icon2 = self:child("Tip-Frame-Icon2")
    self._lb_icon2:SetHeight({0, 3})
    self._lb_icon3 = self:child("Tip-Frame-Icon3")
    self._lb_icon3:SetHeight({0, 3})
	self._lb_dir = {
		[DIR_LEFT]		    = self:child("Tip-Left"),
		[DIR_RIGHT]		    = self:child("Tip-Right"),
		[DIR_TOP]		    = self:child("Tip-Top"),
		[DIR_BOTTOM]	    = self:child("Tip-Bottom")
	}

	self._cancel = nil
end

local offset = 16
local curGuide = nil
function M:adjust(target, dir, pos_x, pos_y, radius, curNode, pw, ph)
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
    temp_Posx = posx
	if not dir then
	    if math.abs(dx) > math.abs(dy) then
	    	if dx > 0 then
	    		-- left
	    		dir = DIR_RIGHT
                if temp_TextLength > sw/2 then
                    isTextExceed = true
                end
	    	else
	    		-- right
	    		dir = DIR_LEFT
                if temp_TextLength > sw/2 then
                    isTextExceed = true
                end
	    	end
	    else
	    	if dy > 0 then
	    		-- top
	    		dir = DIR_BOTTOM
                if posx + temp_TextLength > sw - 30 then
                    dir = DIR_RIGHT
                    isTextExceed = true
                end
	    	else
	    		-- bottom
	    		dir = DIR_TOP
                 if posx + temp_TextLength > sw - 30 then
                    dir = DIR_RIGHT
                    isTextExceed = true
                end
	    	end
	    end
    end

	if dir == DIR_RIGHT then
		posx = ll - w - offset
        posy = lt
    elseif dir == DIR_LEFT then
        posx = lr  + offset
        posy = lt
    elseif dir == DIR_BOTTOM then
        posy = lt - h - offset
        posx = ll
    elseif dir == DIR_TOP then
        posy = lb + offset
        posx = ll
    end


--	for k, v in pairs(self._lb_dir) do
--		if k == dir then
--			v:SetVisible(true)
--		else
--			v:SetVisible(false)
--		end
--	end
    local targetWnd = target
    local area = targetWnd:GetRenderArea()
	if not curGuide then
		curGuide = curNode
		if pos_x and pos_y then
			local window = UI:openWnd("guide_mask")
            window:child("Mask-guideMask"):setPierceArea(area)
            if radius then
			    window:updateMask(pos_x - pw, pos_y - ph, radius)
            else
                window:setMask(area)
            end
		end
	elseif curGuide ~= curNode then
		curGuide = curNode
		--UI:closeWnd("guide_mask")
	elseif curGuide == curNode then
		if pos_x and pos_y then
			local window = UI:openWnd("guide_mask")
            window:child("Mask-guideMask"):setPierceArea(area)
			if radius then
			    window:updateMask(pos_x - pw, pos_y - ph, radius)
            else
                window:setMask(area)
            end
		end
	end

	self:root():SetXPosition({0, posx})
	self:root():SetYPosition({0, posy})
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

function M:attach(target, text, dir, radius, curNode, cb, event, isFollow)
	assert(event, tostring(event))
	self.reloadArg = table.pack(target, text, dir, radius, curNode, cb)
	if not target then
		return
	end

    local btnWnd = UI:openWnd("mapEditGuideNextSkip")
    btnWnd:onOpen(target)

	self._lb_desc:SetText(Lang:toText(text))
	local height = self._lb_icon1:GetHeight()
    
    local length = {0, self._lb_desc:GetFont():GetTextExtent(Lang:toText(text),1.0)}
    local sw = GUISystem.instance:GetScreenWidth()
    local proportion =sw/1024
    temp_TextLength = (self._lb_desc:GetFont():GetTextExtent(Lang:toText(text),1.0) + 60) * proportion
    local w, h = self:root():GetPixelSize().x, self:root():GetPixelSize().y
    if isTextExceed then
--        if temp_Posx - temp_TextLength < 0 or temp_Posx + temp_TextLength > sw then
		if temp_TextLength > 350 then
            isWordWrap = true
        else
            isWordWrap = false
        end
    end

    if isWordWrap and isTextExceed then
        self._lb_desc:SetWordWrap(true)
        self._lb_desc:SetWidth({0, length[2] / 2 + 30})
        self._lb_icon2:SetWidth({0, length[2] / 2 - 50})
    else
        self._lb_desc:SetWidth(length)
        length[2] = length[2] - 60
        self._lb_icon2:SetWidth(length)
    end
    local width1 = self._lb_icon1:GetWidth()
    local width2 = self._lb_icon2:GetWidth()
    local width3 = self._lb_icon3:GetWidth()
    local width = {}
    width[1] = width1[1] + width2[1]
    width[2] = width1[2] + width2[2]
    
    if isWordWrap and isTextExceed then
        self._lb_desc:SetXPosition({0, width1[2] + 10})
        self._lb_icon3:SetXPosition({0, length[2] / 2 - 20})
    else
        self._lb_icon3:SetXPosition(width)
    end
    width[1] = width[1] + width3[1]
    width[2] = width[2] + width3[2]
	self:root():SetHeight(height)
    if isWordWrap and isTextExceed then
        self:root():SetWidth({0, length[2] / 2 + width1[2] + 40})
        isWordWrap = false
        isTextExceed = false
    else
        self:root():SetWidth(width)
    end


	if self._cancel then
		self._cancel()
		self._cancel = nil
	end

	if cb then
		self._cancel = target:subscribe(event, cb)
	end

	-- 获得 target 的 root
	local desktop = GUISystem.instance:GetRootWindow()

	local targetWnd = target
	local area = targetWnd:GetRenderArea()
	local size = targetWnd:GetPixelSize()
	self:adjust(target,dir, area[3], area[4], radius, curNode, size.x/2, size.y/2)

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


	local count = desktop:GetDrawlistCount()
	self:root():ShowOnTop()	-- 先显示到最上
	assert(self:root():getId() == desktop:GetChildByIndexInDrawlist(count - 1):getId())
	if isFollow then
		for index = count - 2, 0, -1 do
			local wnd = desktop:GetChildByIndexInDrawlist(index)
			assert(wnd, index)

			if wnd:getId() == targetWnd:getId() then
				break
			end

			self:root():MoveBack()
		end
	end
end

function M:onClose()
    UI:closeWnd("mapEditGuideNextSkip")
end

function M:onReload(reloadArg)
	local target, text, dir, radius, curNode, cb = table.unpack(reloadArg or {}, 1, reloadArg and reloadArg.n)
	self:attach(target, text, dir, radius, curNode, cb)
end

return M

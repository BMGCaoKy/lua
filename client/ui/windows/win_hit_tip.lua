local setting = require "common.setting"

function M:init()
	WinBase.init(self, "AttackHitTip.json", true)
	self.queue = {}		-- 待显示的区间队列
	self.index = 0		-- 当前显示区间的队列索引
	self.current = 0	-- 当前显示的数字
	Lib.subscribeEvent(Event.EVENT_UPDATE_HIT_COUNT, function(start, finish, imageSet)
		if start > finish then
			UI:closeWnd(self)
			return
		end
		local queue = self.queue
		queue[#queue + 1] = { start, finish, imageSet }
		if not self.tweenTimer then
			self:showHitCount()
		end
	end)
end

function M:onOpen()
	WinBase.onOpen(self)
	self:showHitCount()
end

function M:onClose()
	self.queue = {}
	self.index = 0
	self.current = 0
	self:closeTweenTimer()
	self:child("AttackHitTip-Numbers"):CleanupChildren()
	WinBase.onClose(self)
end

function M:closeTweenTimer()
	local timer = self.tweenTimer
	if timer then
		timer()
		self.tweenTimer = nil
	end
end

function M:showHitCount()
	local queue = self.queue
	local index = math.max(self.index, 1)
	local range = queue[index]
	if not range then
		return
	end
	local hitCount = math.max(self.current, range[1])
	local imageSet = range[3]

	self:child("AttackHitTip-Numbers"):CleanupChildren()
	local grid = UILib.makeNumbersGrid("AttackHitTip-Numbers-Grid", hitCount, imageSet)
	grid:SetHorizontalAlignment(1)	-- middle
	grid:SetVerticalAlignment(2)	-- bottom
	local numberLen = tostring(hitCount):len()
	local xOffset = math.max(3 - numberLen, 0) * 25 + 20
	local areaX, areaY = {0, xOffset}, {0, 0}
	local width = numberLen * 45
	grid:SetArea(areaX, areaY, {0, width}, {1, 0})
	self:child("AttackHitTip-Numbers"):AddChildWindow(grid)

	self.tweenTimer = UILib.zoomTween(grid, 1, 0, 1.2, 1, function()
		self.current = hitCount + 1
		if hitCount < range[2] then		-- next count
			self.current = hitCount + 1
			self:showHitCount()
		elseif queue[index + 1] then	-- next range
			self.current = 0
			self.index = index + 1
			self:showHitCount()
		else							-- finished
			self.queue = {}
			self.index = 0
			self.current = 0
			self:closeTweenTimer()
			grid:SetArea(areaX, areaY, {0, width}, {1, 0})
		end
	end)
end

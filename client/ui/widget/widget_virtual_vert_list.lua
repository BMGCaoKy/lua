---@class widget_virtual_vert_list : CEGUIScrollableView
local M = {}

---@return widget_virtual_vert_list
---@param messageView CEGUIScrollableView
---@param msgList CEGUIScrolledContainer
---@param createFunc fun(self : widget_virtual_vert_list, msgList : CEGUIScrolledContainer)
---@param initFunc fun(self : widget_virtual_vert_list, child : CEGUILayout, data : table)
function M:init(messageView, msgList, createFunc, initFunc)
	messageView.onContentPaneScrolled = function (self, window)
		self:onVirtualContentPaneScrolled(window)
	end
	messageView.onSized = function (self)
		self:onVirtualSized()
	end

	--local obj = Lib.derive(self, messageView)
	messageView.__base = messageView.__base or {}
	table.insert(messageView.__base, self)

	local mt = getmetatable(messageView)
	local obj = setmetatable(messageView, {
			__index = function (instance, key)
				for _, self in ipairs(messageView.__base) do
					if self[key] then
						return self[key]
					end
				end
				return mt.__index(instance, key)
			end,
			__newindex = mt.__newindex
		}
	)

	obj.virtualData = {}
	obj.msgList = msgList
	obj.initChild = initFunc
	obj.createFunc = createFunc
	if createFunc then
		obj.childTemp = obj:createFunc(obj:getWindow())
		obj.childTemp:setProperty("MousePassThroughEnabled","true")
		obj.childTemp:setVisible(false)
	end
	return obj
end

-- 添加子节点
function M:addVirtualChild(data)
	local child = self.childTemp
	if self:checkCreateChild() then
		child = self:createFunc(self.msgList)
	end

	local oldOffset = self:getOffset()

	self:addChild(child, data)

	self:updateTopBottomOffset(oldOffset)
end

-- 添加子节点(list)
function M:addVirtualChildList(dataList)
	dataList = dataList or {}

	if #dataList > 0 then
		local oldOffset = self:getOffset()

		for i = 1, #dataList do
			self:addChild(self.childTemp, dataList[i])
		end
	
		self:updateTopBottomOffset(oldOffset)
	end
end

-- 删除子节点(从1开始)
function M:delVirtualChild(index)
	if index < 1 or index > #self.virtualData then
		return
	end

	local nextIndex = index + 1
	local deltaPosY = 0
	if nextIndex <= #self.virtualData then
		deltaPosY = self.virtualData[nextIndex].posY - self.virtualData[index].posY
		for i = nextIndex, #self.virtualData do
			local data = self.virtualData[i]
			data.posY = data.posY - deltaPosY
		end
	end
	table.remove(self.virtualData, index)

	self:updateTopBottomOffset()
end

-- 删除子节点(数据)
function M:delVirtualChildByData(data)
	if not data then
		return
	end

	local index = 0
	for i, v in ipairs(self.virtualData) do
		if v == data then
			index = i
			break
		end
	end

	if index ~=  0 then
		self:delVirtualChild(index)
	end
end

-- 删除所有子节点
function M:clearVirtualChild()
	self.virtualData = {}
	self.msgList:cleanupChildren()
	self.msgList:setProperty("startOffset", 0)
	self.msgList:setProperty("endOffset", 0)
end

-- 获取子节点数
function M:getVirtualChildCount()
	return #self.virtualData
end

-- 获取滑动条位置(0 - 1)
function M:getVirtualBarPosition()
	return self.getWindow():getVerticalScrollPosition()
end

-- 设置滑动条位置(0 - 1)
function M:setVirtualBarPosition(pos)
	World.Timer(1, function()
		self.getWindow():setVerticalScrollPosition(pos)
	end)
end

-- 更新子节点数据(list)
function M:refresh(dataList)
	dataList = dataList or {}
	self.virtualData = self.virtualData or {}

	if #self.virtualData ~= #dataList then
		if #dataList > 0 then
			self.virtualData = {}
			self.msgList:setProperty("startOffset", 0)
			self.msgList:setProperty("endOffset", 0)
			self:addVirtualChildList(dataList)
		else
			self:clearVirtualChild()
		end
		return
	end

	local oldOffset = self:getOffset()

	for i = 1, #dataList do
		self.virtualData[i].data = dataList[i]
	end

	self:updateTopBottomOffset(oldOffset)
end

function M:getOffset()
	local window = self:getWindow()

	local view = window:getViewableArea()
	local bar = window:getVerticalScrollPosition()

	local viewHeight = view.bottom - view.top
	local paneHeight = self:getVirtualSize()[2]

	if viewHeight >= paneHeight then
		return {0, 0}
	end

	local deltaHeight = paneHeight - viewHeight
	local offsetY = deltaHeight * bar
	return {0, offsetY}
end

function M:getVirtualSize()
	local paneHeight = 0
	if #self.virtualData > 0 then
		local data = self.virtualData[#self.virtualData]
		paneHeight = data.posY + data.height
	end
	return {0, paneHeight}
end

function M:checkCreateChild()
	local window = self:getWindow()
		
	local view = window:getViewableArea()
	local bar = window:getVerticalScrollPosition()

	local viewHeight = view.bottom - view.top
	local paneHeight = self:getVirtualSize()[2]

	if viewHeight >= paneHeight then
		if #self.virtualData >= self.msgList:getChildCount() then
			return true
		else
			return false
		end
	end

	return false
end

function M:addChild(child, data)
	if not self.initChild then
		return
	end

	self:initChild(child, data)
	local posY = 0
	if #self.virtualData > 0 then
		local d = self.virtualData[#self.virtualData] or {}
		posY = (d.posY or 0) + (d.height or 0) + self.msgList:getSpace()
	end

	table.insert(self.virtualData, {
		data = data,
		posY = posY,
		height = self.msgList:getBoundingSizeForWindow(child)[2][2]
	})
end

function M:updateTopBottomOffset(oldOffset)
	-- oldOffset在子节点增加时有值
	local window = self:getWindow()
	self:updateItems(window, oldOffset, true)
end

function M:onVirtualContentPaneScrolled(window)
	self:updateItems(window)

	if self.onScrolled then
		self:onScrolled(window)
	end
end

function M:onVirtualSized()
	local window = self:getWindow()
	self:updateItems(window, nil, true)
end

function M:updateItems(window, oldOffset, force)
	local view = window:getViewableArea()
	local viewHeight = view.bottom - view.top
	local paneHeight = self:getVirtualSize()[2]
	local offsetY = 0

	if viewHeight < paneHeight then
		if oldOffset then
			offsetY = oldOffset[2]
		else
			local bar = window:getVerticalScrollPosition()
			local deltaHeight = paneHeight - viewHeight
			offsetY = deltaHeight * bar
		end
	end

	local firstDataIndex = 0
	local firstData = nil

	--获取第一个显示数据index
	for i = 1, #self.virtualData do
		firstData = self.virtualData[i]
		local dataHeight = firstData.posY + firstData.height
		if dataHeight > offsetY then
			firstDataIndex = i
			offsetY = offsetY - firstData.posY
			break
		end
	end

	if firstDataIndex == 0 and not force then
		return
	end

	if self.firstDataIndex == firstDataIndex and self.offsetY == offsetY and not force then
		return
	end
	self.offsetY = offsetY

	--设置上方留空
	local posTop = 0
	for i = 1, firstDataIndex - 1 do
		firstData = self.virtualData[i]
		posTop = posTop + firstData.height + self.msgList:getSpace()
	end
	local posDisplay = self.offsetY + posTop + viewHeight

	local itemCount = self.msgList:getChildCount()
	local curItemIndex = 0

	if firstDataIndex > 0 then
		--获取最后一个显示数据index
		local lastDataIndex = firstDataIndex
		for i = lastDataIndex + 1, #self.virtualData do
			firstData = self.virtualData[i]
			if firstData.posY > posDisplay then
				break
			end
			lastDataIndex = i
		end

		if self.firstDataIndex ~= firstDataIndex or self.lastDataIndex ~= lastDataIndex or force then
			self.firstDataIndex = firstDataIndex
			self.lastDataIndex = lastDataIndex
			--设置显示区域内的item
			for i = self.firstDataIndex, self.lastDataIndex do
				firstData = self.virtualData[i]
				firstDataIndex = i

				local child = nil
				if curItemIndex >= itemCount then
					child = self:createFunc(self.msgList)
					itemCount = itemCount + 1
				else
					child = self.msgList:getChildAtIdx(curItemIndex)
				end
				child:setVisible(true)
				if self.initChild then
					self:initChild(child, firstData.data)
					curItemIndex = curItemIndex + 1
				end
			end
			self.msgList:markNeedsLayouting()
		else
			curItemIndex = self.lastDataIndex - self.firstDataIndex + 1
			firstDataIndex = self.lastDataIndex
		end
	end

	local posBottom = 0
	for i = firstDataIndex + 1, #self.virtualData do
		firstData = self.virtualData[i]
		posBottom = posBottom + firstData.height + self.msgList:getSpace()
	end
	for i = curItemIndex, itemCount - 1 do
		local child = self.msgList:getChildAtIdx(i)
		if child then
			--posBottom = posBottom - self.msgList:getSpace() - self.msgList:getBoundingSizeForWindow(child)[2][2]
			child:setVisible(false)
		end
	end

	self.msgList:setProperty("startOffset", posTop)
	self.msgList:setProperty("endOffset", posBottom)
end

return M


local M = {}

--require "common.profiler"
--require "common.profiler_lib"

-- 
function M:init(messageView, msgList, createFunc, initFunc, rowSize)
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

	obj.async = false
	obj.virtualData = {}
	obj.gridsSize = {}
	obj.paneSize = {}
	obj.msgList = msgList
	obj.initChild = initFunc
	obj.createFunc = createFunc
	obj.rowSize = rowSize or 1
	obj.msgList:setRowSize(obj.rowSize)
	local tempParent = obj:getWindow():createChild("DefaultWindow")
	tempParent:setProperty("MousePassThroughEnabled","true")
	tempParent:setVisible(false)
	if createFunc then
		obj.childTemp = obj:createFunc(tempParent)
	end
	return obj
end

function M:initAsync(messageView, msgList, childLayoutName, createCallBackFunc, initFunc, rowSize)
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

	obj.async = true
	obj.childLayoutName = childLayoutName
	obj.virtualData = {}
	obj.gridsSize = {}
	obj.paneSize = {}
	obj.msgList = msgList
	obj.initChild = initFunc
	obj.createFunc = createCallBackFunc
	obj.rowSize = rowSize or 1
	obj.msgList:setRowSize(obj.rowSize)
	local tempParent = obj:getWindow():createChild("DefaultWindow")
	tempParent:setProperty("MousePassThroughEnabled","true")
	tempParent:setVisible(false)
	obj.childTemp = UI:openWidget(childLayoutName)
	tempParent:addChild(obj.childTemp:getWindow())
	return obj
end

-- 添加子节点
function M:addVirtualChild(data)
	local child = self.childTemp
	if self:checkCreateChild() then
		child = child:clone()
		self.itemNameCout = self.itemNameCout or 0
		self.itemNameCout = self.itemNameCout + 1
		child:setName("grid_child_" .. self.itemNameCout)
		self.msgList:addChild(child)
	end

	local oldOffset = self:getOffset()

	self:addChild(child, data)

	self:updateTopBottomOffset(oldOffset)
end

-- 添加子节点(list)
function M:addVirtualChildList(dataList)
	dataList = dataList or {}

	local oldOffset = self:getOffset()
	for _, data in pairs(dataList or {}) do
		self:addChild(self.childTemp, data)
	end
	self:updateTopBottomOffset(oldOffset)
end

-- 删除子节点(从1开始)
function M:delVirtualChild(index)
	-- todo
end

-- 删除子节点(数据)
function M:delVirtualChildByData(data)
	-- todo
end

-- 删除所有子节点
function M:clearVirtualChild()
	self.virtualData = {}
	self.gridsSize = {}
	self.paneSize = {}
	self.msgList:cleanupChildren()
	self.msgList:setVirtualCol(-1)
	self.msgList:setProperty("startXOffset", 0)
	self.msgList:setProperty("startYOffset", 0)
	self.msgList:setProperty("endXOffset", 0)
	self.msgList:setProperty("endYOffset", 0)
end

-- 获取子节点数
function M:getVirtualChildCount()
	return #self.virtualData
end

-- 获取滑动条位置(0 - 1)
function M:getVirtualVertBarPosition()
	return self.getWindow():getVerticalScrollPosition()
end

-- 设置滑动条位置(0 - 1)
function M:setVirtualVertBarPosition(pos)
	World.Timer(1, function()
		self.getWindow():setVerticalScrollPosition(pos)
	end)
end

-- 获取滑动条位置(0 - 1)
function M:getVirtualHorzBarPosition()
	return self.getWindow():getHorizontalScrollPosition()
end

-- 设置滑动条位置(0 - 1)
function M:setVirtualHorzBarPosition(pos)
	World.Timer(1, function()
		self.getWindow():setHorizontalScrollPosition(pos)
	end)
end

-- 更新子节点数据(list)
function M:refresh(dataList)
	dataList = dataList or {}
	self.virtualData = self.virtualData or {}

	if #self.virtualData ~= #dataList then
		if #dataList > 0 then
			self.virtualData = {}
			self.msgList:setProperty("startXOffset", 0)
			self.msgList:setProperty("startYOffset", 0)
			self.msgList:setProperty("endXOffset", 0)
			self.msgList:setProperty("endYOffset", 0)
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
	local hBar = window:getHorizontalScrollPosition()
	local vBar = window:getVerticalScrollPosition()

	local viewWidth = view.right - view.left
	local viewHeight = view.bottom - view.top
	local paneWidth, paneHeight = self:getVirtualSize()

	local offsetX = (viewWidth < paneWidth) and ((paneWidth - viewWidth) * hBar) or 0
	local offsetY = (viewHeight < paneHeight) and ((paneHeight - viewHeight) * vBar) or 0

	return {offsetX, offsetY}
end

function M:getVirtualSize()
	return self.paneSize.width or 0, self.paneSize.height or 0
end

function M:checkCreateChild()
	return false
end

local function getLine(index, rowSize)
	return math.floor(index/rowSize) + 1
end

function M:addChild(child, data)
	if not self.initChild then
		return
	end

	self:initChild(child, data)

	local boundingSize = self.msgList:getBoundingSizeForWindow(child)
	local newChildWigth = boundingSize[1][2]
	local newChildHeight = boundingSize[2][2]

	local posX = 0
	local posY = 0
	local line = 1

	local paneWidth = self.paneSize.width or 0
	local paneHeight = self.paneSize.height or 0

	paneWidth = paneWidth > newChildWigth and paneWidth or newChildWigth
	paneHeight = paneHeight > newChildHeight and paneHeight or newChildHeight

	if #self.virtualData > 0 then
		local d = self.virtualData[#self.virtualData] or {}
		
		local oldline = getLine(#self.virtualData - 1, self.rowSize)
		line = getLine(#self.virtualData, self.rowSize)
		self.gridsSize[line] = self.gridsSize[line] or {}
		local gridSize = self.gridsSize[line]
		gridSize.posY = gridSize.posY or 0
		gridSize.height = gridSize.height or 0

		if oldline == line then
			posX = (d.posX or 0) + (d.width or 0) + self.msgList:getHInterval()

			if gridSize.height < newChildHeight then
				gridSize.height = newChildHeight
				local newPaneHeight = gridSize.posY + gridSize.height
				paneHeight = (paneHeight > newPaneHeight) and newPaneHeight or newPaneHeight
			end

			posY = gridSize.posY

			local newPaneWidth = posX + newChildWigth
			paneWidth = (paneWidth > newPaneWidth) and paneWidth or newPaneWidth
		else
			local oldGridSize = self.gridsSize[oldline]
			gridSize.posY = oldGridSize.posY + oldGridSize.height + self.msgList:getVInterval()
			gridSize.height = newChildHeight
			posY = gridSize.posY
			local newPaneHeight = gridSize.posY + gridSize.height
			paneHeight = (paneHeight > newPaneHeight) and newPaneHeight or newPaneHeight
		end
	end

	table.insert(self.virtualData, {
		data = data,
		posX = posX,
		posY = posY,
		width = newChildWigth,
		height = newChildHeight
	})

	if #self.virtualData > 0 and not self.gridsSize[1] then
		self.gridsSize[1] = {posY = 0, height = paneHeight}
	end
	self.paneSize.width = paneWidth
	self.paneSize.height = paneHeight
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
	--Profiler:begin("updateItems")
	if #self.virtualData == 0 then
		--Profiler:finish("updateItems")
		return
	end

	local view = window:getViewableArea()
	local viewWidth = view.right - view.left
	local viewHeight = view.bottom - view.top

	local paneWidth, paneHeight = self:getVirtualSize()
	local offsetX = 0
	local offsetY = 0

	if viewWidth < paneWidth then
		offsetX = oldOffset and oldOffset[1] or ((paneWidth - viewWidth) * window:getHorizontalScrollPosition())
	end

	if viewHeight < paneHeight then
		offsetY = oldOffset and oldOffset[2] or ((paneHeight - viewHeight) * window:getVerticalScrollPosition())
	end

	local startLine = 1
	local startYOffset = 0
	for line = startLine, #self.gridsSize do
		local gridSize = self.gridsSize[line]
		if gridSize.posY + gridSize.height > offsetY then
			startLine = line
			startYOffset = gridSize.posY
			break
		end
	end

	local showHeight = offsetY + viewHeight
	local endLine = startLine
	local endYOffset = 0
	for line = endLine + 1, #self.gridsSize do
		local gridSize = self.gridsSize[line]
		if gridSize.posY >= showHeight then
			endYOffset = paneHeight - gridSize.posY
			break
		end
		endLine = line
	end

	local showWidth = offsetX + viewWidth
	local endCol = 1
	local startCol = self.rowSize
	local startXOffset = -1
	local endXOffset = -1
	for line = startLine, endLine do
		local startIndex = (startLine - 1) * self.rowSize
		local setEnd = false
		for col = 1, self.rowSize do
			local data = self.virtualData[startIndex + col]
			if not data then
				break
			end
			if not setEnd then
				if data.posX + data.width > offsetX then
					if startCol > col then
						startCol = col
						if startXOffset == -1 then
							startXOffset = data.posX
						else
							if startXOffset > data.posX then
								startXOffset = data.posX
							end
						end
						if endCol < col then
							endCol = col
							local deltaW = paneWidth - data.posX - data.width
							if endXOffset == -1 then
								endXOffset = deltaW
							else
								if endXOffset < deltaW then
									endXOffset = deltaW
								end
							end
						end
					end
					setEnd = true
				end
			else
				if data.posX >= showWidth then
					break
				end
				if endCol < col then
					endCol = col
					local deltaW = paneWidth - data.posX - data.width
					if endXOffset == -1 then
						endXOffset = deltaW
					else
						if endXOffset > deltaW then
							endXOffset = deltaW
						end
					end
				end
			end
		end
	end

	if self.startLine == startLine and self.startCol == startCol and self.endLine == endLine and self.endCol == endCol and not force then
		--Profiler:finish("updateItems")
		return
	end

	startXOffset = startXOffset == -1 and 0 or startXOffset
	endXOffset = endXOffset == -1 and 0 or endXOffset

	self.startLine = startLine
	self.endLine = endLine
	self.startCol = startCol
	self.endCol = endCol

	local itemIndex = 0
	local itemCount = self.msgList:getChildCount()

	local needLayout = false
	for line = startLine, endLine do
		local startIndex = (line - 1) * self.rowSize
		for col = startCol, endCol do
			local data = self.virtualData[startIndex + col]
			if data then

				local child = nil
				if itemIndex < itemCount then
					child = self.msgList:getChildAtIdx(itemIndex)
					child:setVisible(true)
					if self.initChild then
						self:initChild(child, data.data)
						itemIndex = itemIndex + 1
						needLayout = true
					end
				else
					self.itemNameCout = self.itemNameCout or 0
					self.itemNameCout = self.itemNameCout + 1
					if self.async then
						UI:openWindowAsync(function(gridItem)
							self.msgList:addChild(gridItem:getWindow())
							gridItem:setVisible(true)
							if self.initChild then
								self:initChild(gridItem, data.data)
								itemIndex = itemIndex + 1
								needLayout = true
							end
							self:createFunc(gridItem)
						end, self.childLayoutName, "grid_child_" .. self.itemNameCout)
					else
						child = self:createFunc(self.msgList)
						child:setName("grid_child_" .. self.itemNameCout)
						child:setVisible(true)
						itemCount = itemCount + 1
						if self.initChild then
							self:initChild(child, data.data)
							itemIndex = itemIndex + 1
							needLayout = true
						end
					end
				end

			end
		end
	end

	for i = itemIndex, itemCount - 1 do
		local child = self.msgList:getChildAtIdx(i)
		if child then
			child:setVisible(false)
		end
	end

	if needLayout then
		self.msgList:markNeedsLayouting()
	end
	self.msgList:setProperty("startXOffset", startXOffset)
	self.msgList:setProperty("startYOffset", startYOffset)
	self.msgList:setProperty("endXOffset", endXOffset)
	self.msgList:setProperty("endYOffset", endYOffset)
	self.msgList:setVirtualCol(self.endCol - self.startCol + 1)
	--Profiler:finish("updateItems")
end

return M

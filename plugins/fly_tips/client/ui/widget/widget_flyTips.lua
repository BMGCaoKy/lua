local widget_base = require "ui.widget.widget_base"
---@class WidgetFlyTips : widget_base
local WidgetFlyTips = Lib.derive(widget_base)

local flyTipsSetting = World.cfg.fly_tipsSetting or {}
function WidgetFlyTips:init()
	widget_base.init(self, "FlyTips.json")
	self:initUI()
	self:initEvent()
end

function WidgetFlyTips:initUI()
	self.imgFlyTipsTipBg = self:child("FlyTips-tip_bg")
	self.lytFlyTipsTipNormal = self:child("FlyTips-tip_normal")
	self.txtFlyTipsTipNormalStr = self:child("FlyTips-tip_normalStr")
	self.lytFlyTipsTipGain = self:child("FlyTips-tip_gain")
	self.txtFlyTipsTipGainStr1 = self:child("FlyTips-tip_gainStr1")
	self.txtFlyTipsTipGainStr2 = self:child("FlyTips-tip_gainStr2")
	self.txtFlyTipsTipGainStr3 = self:child("FlyTips-tip_gainStr3")
	self.txtFlyTipsTipGainStr4 = self:child("FlyTips-tip_gainStr4")
	self.imgFlyTipsGainIcon1 = self:child("FlyTips-tip_gainIcon1")
	self.imgFlyTipsGainIcon2 = self:child("FlyTips-tip_gainIcon2")

	self.txtNewTipsNode = {}
	for i = 1, 4 do
		self.txtNewTipsNode[i] = self:child("FlyTips-tip_gainStr" .. i)
	end
	self.imgNewTipsNode = {}
	for i = 1, 2 do
		self.imgNewTipsNode[i] = self:child("FlyTips-tip_gainIcon" .. i)
		if flyTipsSetting.gainIconSize then
			self.imgNewTipsNode[i]:SetWidth({0, flyTipsSetting.gainIconSize[1]})
			self.imgNewTipsNode[i]:SetHeight({0, flyTipsSetting.gainIconSize[2]})
		else
			self.imgNewTipsNode[i]:SetWidth({0, 30})
			self.imgNewTipsNode[i]:SetHeight({0, 30})
		end
	end

	if flyTipsSetting.tipsBgRes and flyTipsSetting.tipsBgRes ~= "" then
		self.imgFlyTipsTipBg:SetImage(flyTipsSetting.tipsBgRes)
	end

	self:root():SetLevel(flyTipsSetting.tipsLevel)
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetFlyTips:initEvent()
end

function WidgetFlyTips:initItemData(itemInfo)
	self:root():SetYPosition({0, flyTipsSetting.initPosY})
	self:updateAllNodeAlpha(1)
	self:root():SetVisible(true)
	if itemInfo.type == 1 then
		self:showFlyTipsInfo1(itemInfo)
	elseif itemInfo.type == 2 then
		self:showFlyTipsInfo2(itemInfo)
	else
		self:showFlyTipsInfo1(itemInfo)
	end
end

function WidgetFlyTips:setItemYPosition(posY)
	self:root():SetYPosition({0, posY})
end

function WidgetFlyTips:getItemYPosition()
	return self:root():GetYPosition()[2]
end

function WidgetFlyTips:updateAllNodeAlpha(alpha)
	self:root():SetAlpha(alpha)
	local num = self:root():GetChildCount()
	for i = 1, num do
		local win = self:root():GetChildByIndex(i - 1)
		win:SetAlpha(alpha)
	end
	if alpha <= 0 then
		self:root():SetVisible(false)
	else
		self:root():SetVisible(true)
	end
end

function WidgetFlyTips:setCreateTime(createTime)
	self.createShowTime = createTime
end

function WidgetFlyTips:getCreateTime()
	return self.createShowTime or 0
end

function WidgetFlyTips:setStartActionTime(startTime)
	self.startActionTime = startTime
end

function WidgetFlyTips:getStartActionTime()
	return self.startActionTime or 0
end

local function getTextColor(str)
	-- 去掉#字符
	local newstr = string.gsub(str, '#', '')

	-- 每次截取两个字符 转换成十进制
	local colorlist = {}
	local index = 1
	while index < string.len(newstr) do
		local tempstr = string.sub(newstr, index, index + 1)
		table.insert(colorlist, tonumber(tempstr, 16))
		index = index + 2
	end
	return { (colorlist[1] or 0)/ 255, (colorlist[2] or 0)/ 255, (colorlist[3] or 0)/ 255 }
end

-- 纯文本提示
function WidgetFlyTips:showFlyTipsInfo1(itemInfo)
	local msg = itemInfo.content or ""
	self.lytFlyTipsTipNormal:SetVisible(true)
	self.lytFlyTipsTipGain:SetVisible(false)
	self.txtFlyTipsTipNormalStr:SetText(Lang:toText(msg))
	self.txtFlyTipsTipNormalStr:SetTextColor( getTextColor(flyTipsSetting.normalColor))
	self.txtFlyTipsTipNormalStr:SetFontSize(flyTipsSetting.normalFont or "HT20")
end

-- 文本+图片
function WidgetFlyTips:showFlyTipsInfo2(itemInfo)
	self.lytFlyTipsTipNormal:SetVisible(false)
	self.lytFlyTipsTipGain:SetVisible(true)

	for i, _ in pairs(self.txtNewTipsNode) do
		self.txtNewTipsNode[i]:SetVisible(false)
	end
	for i, _ in pairs(self.imgNewTipsNode) do
		self.imgNewTipsNode[i]:SetVisible(false)
	end

	local contentNodeList = {}
	local textIndex, imgIndex = 0,0
	for key, val in pairs(itemInfo.contentData) do
		local temp = {}
		if val.contentType == Define.FlyTipsContentType.Text then
			textIndex = textIndex + 1
			if self.txtNewTipsNode[textIndex] then
				temp.node = self.txtNewTipsNode[textIndex]
				temp.contentType = val.contentType
				temp.contentInfo = Lang:toText(val.contentInfo or "")
				temp.node:SetVisible(true)
				temp.node:SetText(temp.contentInfo)
				temp.node:SetFontSize(val.contentFont or flyTipsSetting["gainFont" .. textIndex] or "HT20")
				temp.node:SetTextColor(getTextColor(val.contentColor or flyTipsSetting["gainColor" .. textIndex] or "FFFFFF"))
			end
		elseif val.contentType == Define.FlyTipsContentType.Image then
			imgIndex = imgIndex + 1
			if self.imgNewTipsNode[imgIndex] then
				temp.node = self.imgNewTipsNode[textIndex]
				temp.contentType = val.contentType
				temp.node:SetVisible(true)
				temp.node:SetImage(val.contentInfo or "")
			end
		end
		if next(temp) then
			table.insert(contentNodeList, temp)
		end
	end
	self:updateContentPos(contentNodeList)
end

function WidgetFlyTips:updateContentPos(contentNodeList)
	local iconW = 30
	if flyTipsSetting.gainIconSize then
		iconW = flyTipsSetting.gainIconSize[1]
	end
	local iconDis = 10
	local widgetList = {}
	local totalStrW = 0
	for key, val in pairs(contentNodeList) do
		if val.contentType == Define.FlyTipsContentType.Image then
			widgetList[key] = iconW
			totalStrW = totalStrW + iconDis
		else
			widgetList[key] = val.node:GetFont():GetStringWidth(val.contentInfo or "") or 0
		end
		totalStrW = totalStrW + widgetList[key]
	end

	local initPosX = -totalStrW/2
	local preWidget = initPosX
	for key, val in pairs(contentNodeList) do
		if contentNodeList[key].contentType == Define.FlyTipsContentType.Image then
			contentNodeList[key].node:SetXPosition({0, preWidget +  iconDis/2 + widgetList[key]/2})
			preWidget = preWidget + widgetList[key] + iconDis
		else
			contentNodeList[key].node:SetXPosition({0, preWidget})
			preWidget = preWidget + widgetList[key]
		end
	end
end

return WidgetFlyTips

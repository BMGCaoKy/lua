local msin = math.sin
local mcos = math.cos
local mrad = math.rad
local loadstring = rawget(_G, "loadstring") or load


--@func             : ui缓动函数
--@ui               ：ui窗体
--@PropertyObj      ：最终缓动后的结果属性列表
--@time             ：移动时间
--@finishBackF      ：缓动结束回调函数
--@exmaple
            -- local desktop = GUISystem.instance:GetRootWindow()
            -- local win = UILib.showNumberUi(packet.score, packet.pos)
            -- local targetY = win:GetYPosition()[1] - 0.1
            -- UILib.uiTween(win, {
            --     Y = {targetY, 0},
            --     Alpha = 0
            -- }, 20, function()
            --     desktop:RemoveChildWindow1(win)
            -- end)
function UILib.uiTween(ui, PropertyObj, time, finishBackF)
	local getPropertyToList = function()
		local result = {}
		for key, value in pairs(PropertyObj) do
			local targetValue = {}
			if type(value) == "table" then
				for _, v in pairs(value) do
					targetValue[#targetValue + 1] = v
				end
				targetValue = "{" .. table.concat( targetValue, ",") .. "}"
			else
				targetValue = tostring(value)
			end

			result[#result + 1] = {
				name = tostring(key),
				targetValue = targetValue
			}
		end
		return result
	end
	local propertyList = getPropertyToList()
	Blockman.instance:uiTweenTo(ui,propertyList, time)
	World.Timer(time, function()
		if finishBackF then
			finishBackF()
		end
	end)
end

function UILib.zoomTween(window, zoomInTicks, zoomOutTicks, maxScale, finalScale, finishCallback)
	local tickCount = 0
	if not finalScale then
		finalScale = 1
	end
	local width = window:GetWidth()
	local height = window:GetHeight()
	local timer = World.Timer(1, function()
		if tickCount > zoomInTicks + zoomOutTicks then
			if finishCallback then
				finishCallback()
			end
			return false
		end
		local scale = 1
		if tickCount <= zoomInTicks then
			scale = (maxScale - 1) * tickCount / zoomInTicks + 1
		elseif zoomOutTicks > 0 then
			scale = (maxScale - finalScale) * (1 - (tickCount - zoomInTicks) / zoomOutTicks) + finalScale
		end
		window:SetWidth({width[1] * scale, width[2] * scale})
		window:SetHeight({height[1] * scale, height[2] * scale})
		tickCount = tickCount + 1
		return true
	end)
	return timer
end

-- 比较通用的做法：{pic1, pic2, pic3 ...}
-- 将所有需要的资源（图标、艺术字等）放进一个图集
-- 按显示顺序组一个table，从图集里读出来生成UI即可
function UILib.makeTextUIGrid(name, textList, imgset)
	local grid = GUIWindowManager.instance:CreateGUIWindow1("Layout", name)
	local len = #textList
	local widthSum = 0;
	local maxHeight = 0;

	-- 拿到字体
	local imageset = GUIImagesetManager.Instance():createOrRetrieveImageset(imgset .. ".json")
	imageset:load()
	for i = 1, len do
		local ch = textList[i]
		local image = imageset:GetImage(ch)
		if not image then
			Lib.logError("imageset:GetImage nil", imgset .. ".json", ch)
		else
			widthSum = widthSum + image:GetWidth()
			maxHeight = math.max(maxHeight, image:GetHeight())
		end
	end
	widthSum = widthSum

	local width, height
	local x = 0
	for i = 1, len do
		local ch = textList[i]
		local image = imageset:GetImage(ch)
		if image then
			local item = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", tostring(i))
			local imgFile = string.format("set:%s.json image:%s", imgset or "number_mla", ch)
			item:SetImage(imgFile)
			item:SetTouchable(false)
			item:SetProperty("Material", "CullBackLinear")

			width = image:GetWidth()
			height = image:GetHeight()
			grid:AddChildWindow(item)
			if ch == "." then
				item:SetArea({x/widthSum, 0}, {0.5, 0}, {width/widthSum, 0}, {height/maxHeight, 0})
			else
				item:SetArea({x/widthSum, 0}, {(maxHeight - height) / maxHeight / 2, 0}, {width/widthSum, 0}, {height/maxHeight, 0})
			end
			x = x + width
		end
	end
	--销毁
	GUIImagesetManager.Instance():releaseResource(imageset)
	return grid, widthSum, maxHeight
end

function UILib.makeNumbersGrid(name, number, imgset, imgfmt)
	local grid = GUIWindowManager.instance:CreateGUIWindow1("GridView", name)
	grid:SetItemAlignment(1)    
	local numStr = tostring(number)
	local len = string.len(numStr)
	grid:InitConfig(1, 1, len)
	for i = 1, len do
		local num = numStr:sub(i, i)
		local item = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", tostring(i))
		item:SetImage(string.format("set:%s.json image:%s.%s", imgset or "number_mla", num, imgfmt or "png"))
		item:SetAutoSize(true)
		item:SetArea({0, 0}, {0, 0}, {0.95 / len, 0}, {1, 0})
		grid:AddItem(item)
	end
	grid:SetTouchPierce(true)
	grid:SetAutoColumnCount(false)
	return grid
end

function UILib.makeImagesGrid(images)
    assert(images and #images > 0)
    local count = #images
    local grid = GUIWindowManager.instance:CreateGUIWindow1("GridView", "images")
	grid:SetItemAlignment(1)    
	grid:InitConfig(1, 1, count)
    for i, imagePath in ipairs(images) do
        local item = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", tostring(i))
		item:SetImage(imagePath)			
		item:SetAutoSize(true)
		item:SetArea({0, 0}, {0, 0}, {1 / count, 0}, {1, 0})
		grid:AddItem(item)
    end
	grid:SetTouchPierce(true)
	grid:SetAutoColumnCount(false)
	return grid
end

function UILib.UIFromImage(imagePath, size)
    local image = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "image")
    local width = size and size.width or {0, 100}
    local height = size and size.height or {0, 100}
    image:SetArea({0, 0}, {0, 0}, width, height)
    image:SetImage(imagePath)
    return image
end

function UILib.showUIOnVector3Pos(ui, pos, params)
    local result = Blockman.instance:getScreenPos(pos)
    local scale = 11 / result.c

	local size = Lib.copy(params.uiSize)
    local width = size.width
    local height = size.height
    if params and params.autoScale and params.uiSize then

        for key, value in pairs(width) do
            width[key] = value * scale
        end
        for key, value in pairs(height) do
            height[key] = value * scale
        end
		ui:SetWidth(width)
		ui:SetHeight(height)
    end
	local anchor = params.anchor
	local anchorX = anchor and anchor.x or 0
	local anchorY = anchor and anchor.y or 0
	local disX = {
		anchorX * width[1],
		anchorX * width[2],
	}
	local disY = {
		anchorY * height[1],
		anchorY * height[2],
	}
	if math.abs(result.z)  < result.w then
		ui:SetXPosition({result.x - disX[1], -disX[2]})
		ui:SetYPosition({result.y - disY[1], -disY[2]})
	else
		ui:SetXPosition({-1, 0})
	end
end

function UILib.uiFollowPos(ui, pos, params)
	Blockman.instance:createFollowPosWindow(pos,ui, params)
	return function()
		Blockman.instance:removeFollowWindow(ui)
	end
end

function UILib.uiFollowObject(ui, objID, params)
	if not params then
		params = {}
	end
    local object = World.CurWorld:getObject(tonumber(objID))
    if not object or not object:isValid() then
        return
    end

	local autoScale = false
	local rateTime = 1
	local offset = Lib.v3(0, 0, 0)
	local anchor = params.anchor

	params.anchorX = anchor and anchor.x or 0.5
	params.anchorY = anchor and anchor.y or 0.5
	params.autoScale = params.autoScale or autoScale
    params.minScale = params.minScale or 0.5
    params.maxScale = params.maxScale or 1.5 
	params.offset = params.offset and  Lib.tov3(params.offset) or offset
	if params.autoAddDeskop == nil then
		params.autoAddDeskop = false
	end
    if params.canAroundYaw == nil then
		params.canAroundYaw = false
    end
	rateTime = params.rateTime or rateTime
	local autoAddDeskop = params.autoAddDeskop
    local desktop = GUISystem.instance:GetRootWindow()
	if autoAddDeskop then
		ui:SetLevel(100)
		desktop:AddChildWindow(ui)
	end
	Blockman.instance:createFollowObjectWindow(objID, ui, params)
    local stopTimer = World.Timer(rateTime, function()
        if not object:isValid() then
			Blockman.instance:removeFollowWindow(ui)
            return
        end
		if params.showRange then
			local MePos = Me:getPosition()
			if (Lib.v3(MePos.x, MePos.y, MePos.z) - object:getPosition()):len() > params.showRange then
				Blockman.instance:removeFollowWindow(ui)
				return
			end
		end
        return true
    end)
	return function()
		stopTimer()
		Blockman.instance:removeFollowWindow(ui)
	end
end

function UILib.autoLayoutCircle(params)
	-- clockwise layout
	local count = params.count or 1
	assert(count > 0, count)
	local radius = params.radius or 50
	local deltaAngle = count == 1 and 0 or params.deltaAngle
    local startAngle = params.startAngle or 0
	if not deltaAngle then
		local endAngle = params.endAngle or 360
		while endAngle < startAngle do
			endAngle = endAngle + 360
		end
		local angle = endAngle - startAngle
		if math.fmod(angle, 360) == 0 then
			deltaAngle = angle / count
		else
			deltaAngle = angle / (count - 1)
		end
	end
	local curAngle = startAngle
	local posCfgs = {}
	for i = 1, count do
		local formatAngle = mrad(curAngle)
		local pos = {
			x = radius * msin(formatAngle),
			y = -1 * radius * mcos(formatAngle),
		}
		posCfgs[#posCfgs + 1] = pos
		curAngle = curAngle + deltaAngle
	end
	return posCfgs
end

function UILib.createTab()
	
end

function UILib.createButton(params, backFunc)
    local ui = UIMgr:new_widget("settingBtn")
    ui:invoke("fillData", params)
    ui:invoke("setBackFunc", backFunc)
    return ui
end

function UILib.createSingleChoice(params, backFunc)
    local ui = UIMgr:new_widget("singleChoice")
    ui:invoke("fillData", params)
    ui:invoke("setBackFunc", backFunc)
    return ui
end

function UILib.createSlider(params, backFunc)
	local ui = UIMgr:new_widget("slider")
	ui:invoke("fillData", params)
	ui:invoke("setBackFunc", backFunc)
	return ui, 23
end

function UILib.createSwitch(params, backFunc)
	local ui = UIMgr:new_widget("switch")
	ui:invoke("fillData", params)
	ui:invoke("setBackFunc", backFunc)
	return ui
end

function UILib.openShopSetting(params, backFunc)
	UI:openMultiInstanceWnd("mapEditTabSetting", {
		data = {
			limit = params.limit or 1,
			num = params.num or 10,
			price = params.price or 100,
			coinName = params.coinName or "iron_ingot",
			fullName = params.itemName,
			backFunc = backFunc
		},
		labelName = {
			{
				leftName = "editor.ui.baseProp",
				wndName = "ShopSellSetting"
			}
		},
	})
end

function UILib.openCountUI(value, backFunc, onTop)
	local ui = UIMgr:new_widget("leftTab")
	if onTop then
		ui:SetLevel(1)
	end
	local desktop = GUISystem.instance:GetRootWindow()
	desktop:AddChildWindow(ui)
	ui:invoke("fillData", {
		sureOnSaveBackFunc = function(result, isInfinity)
			if backFunc then
				local backData = result[1][1]
				backFunc(backData.value, backData.isInfinity)
			end
			desktop:RemoveChildWindow1(ui)
		end,
		cancelFunc = function()
			desktop:RemoveChildWindow1(ui)
		end,
		detailsData = true,
		tabDataList = {
			{
				leftTabName = "editor.ui.setCount",
				widgetName = "baseProp",
				params = {
					dataUIList = {
						{
							type = "slider",
							index = 1, 
							value = value,
						}
					}
				}
			}
		}
	})
  end

function UILib.test(pos)
	UI:openWnd("mapEditEntityPosUI", { 
		pos = pos, 
		uiShowList = 
		{
			{
				uiName = "changMonsterModle", 
				backFunc = function() 
					print("test") 
				end
			},
			{
				uiName = "changMonsterModle", 
				backFunc = function() 
					print("test") 
				end
			},			{
				uiName = "changMonsterModle", 
				backFunc = function() 
					print("test") 
				end
			},
		}
	})
end

function UILib.updateMask(cells, startTime, updateTime, stopTime, callBack, radiusRatio, alpha)
    local mask = 0
	local upMask = 1 / ((stopTime - startTime) / 20)
	local temp = (updateTime or 0) - startTime
	if temp > 0 then
		mask = temp / 20 * upMask
	end
	local function updateCellsMask(mask)
		for _, cell in ipairs(cells) do
			if cell then
				cell:setMask(mask, radiusRatio, alpha)
			end
		end
	end
	updateCellsMask(1 - mask)
    local function tick()
        mask = mask + upMask
        if mask >= 1 then
            updateCellsMask(0)
			if callBack then
				callBack()
			end
            return false
        end
        updateCellsMask(1 - mask)
        return true
    end
    return World.Timer(20, tick)
end

function UILib.getItemIcon(itemType, itemName)
    local icon = ""
    if itemType == "Item" then
        local item = Item.CreateItem(itemName)
        icon = item:icon()
    elseif itemType == "Block" then
        local item = Item.CreateItem("/block", 1, function(item)
            item:set_block(itemName)
        end)
        icon = item:icon()
    elseif itemType == "Coin" then
        icon = Coin:iconByCoinName(itemName)
    end
    return icon
end

function UILib.openPayDialog(args, callback)
	local showArgs = {}
	showArgs.titleText = args.titleText
	showArgs.msgText = args.msgText
	local leftCoinId = args.leftCoinId
	if leftCoinId and leftCoinId >= 0 then
		showArgs.leftIcon = Coin:iconByCoinId(args.leftCoinId)
	end
	local rightCoinId = args.rightCoinId
	if rightCoinId and rightCoinId >= 0 then
		showArgs.rightIcon = Coin:iconByCoinId(rightCoinId)
	end
	showArgs.leftText = args.leftText or "cancel_buy"
	showArgs.rightText = args.rightText or "sure_buy"
	UI:openWnd("alternativeDialog", showArgs, callback) 
end

function UILib.openChoiceDialog(args, callback)
	local showArgs = {}
	showArgs.titleText = args.titleText
	showArgs.msgText = args.msgText
	showArgs.leftText = args.leftText or "ui_cancel"
	showArgs.rightText = args.rightText or "ui_sure"
	UI:openWnd("alternativeDialog", showArgs, callback)
end

function UILib.openDialog(text)
	UI:openWnd("mapEditTipPopWnd", text)
end

do
    local function logicPosToScreenPos(dx, dy)
        if not dx or not dy then
            return 0, 0
        end
        local gui = GUISystem.instance
        local sw, sh = gui:GetScreenWidth(), gui:GetScreenHeight()
        local lw, lh = gui:GetLogicWidth(), gui:GetLogicHeight()
        local x, y = dx / lw * sw, dy / lh * sh
        local root = Root.Instance()
        if root:isFixedAspect() then
            local dh = math.ceil(root:getRealHeight()) - math.ceil(sh)
            y = y - (dh > 0 and dh * 0.5 or dh)
        end
        return x, y
    end

    local function checkFunc(func, widget, dx, dy)
        if func then
            func(widget, dx, dy)
        end
    end

    local function onTouchDown(widget, dx, dy, func)
        local x, y = logicPosToScreenPos(dx, dy)
        Blockman.instance.gameSettings:beginMouseMove(x, y)
        checkFunc(func, widget, dx, dy)
    end

    local function onTouchMove(widget, dx, dy, func)
        local x, y = logicPosToScreenPos(dx, dy)
        Blockman.instance.gameSettings:setMousePos(x, y)
        checkFunc(func, widget, dx, dy)
    end

    local function onTouchUp(widget, dx, dy, func)
        local x, y = logicPosToScreenPos(dx, dy)
        Blockman.instance.gameSettings:endMouseMove(x, y)
        checkFunc(func, widget, dx, dy)
    end

    function UILib.removeCameralControl(widget)
        widget:unsubscribe(UIEvent.EventWindowTouchDown)
        widget:unsubscribe(UIEvent.EventWindowTouchMove)
        widget:unsubscribe(UIEvent.EventWindowTouchUp)
        widget:unsubscribe(UIEvent.EventMotionRelease)
    end

    function UILib.addCameraControl(widget, isWndFollow, touchDownFunc, touchMoveFunc, touchUpFunc)
        UILib.removeCameralControl(widget)
        widget:subscribe(UIEvent.EventWindowTouchDown, function(window, dx, dy)
            onTouchDown(window, dx, dy, touchDownFunc)
            if isWndFollow then
                window:setData("dx", dx)
                window:setData("dy", dy)
                window:setData("originX", window:GetXPosition())
                window:setData("originY", window:GetYPosition())
            end
        end)

        widget:subscribe(UIEvent.EventWindowTouchMove, function(window, dx, dy)
            onTouchMove(window, dx, dy, touchMoveFunc)
            if isWndFollow then
                window:SetXPosition({0, window:data("originX")[2] + dx - window:data("dx")})
                window:SetYPosition({0, window:data("originY")[2] + dy - window:data("dy")})
            end
        end)

        widget:subscribe(UIEvent.EventWindowTouchUp, function(window, dx, dy)
            onTouchUp(window, dx, dy, touchUpFunc)
            if isWndFollow then
                window:SetXPosition(window:data("originX"))
                window:SetYPosition(window:data("originY"))
            end
        end)

        widget:subscribe(UIEvent.EventMotionRelease, function(window, dx, dy)
            onTouchUp(window, dx, dy, touchUpFunc)
            if isWndFollow then
                window:SetXPosition(window:data("originX"))
                window:SetYPosition(window:data("originY"))
            end
        end)
    end
end

local function getImageSize(imageName, maxWidth, maxHeight)
	local imageInfo = Lib.splitString(imageName, " ")
	if #imageInfo ~= 2 then
		return { 1, 0 }, { 1, 0 }
	end
	local fileName = imageInfo[1]:gsub("set:", "")
	local imageset = GUIImagesetManager.Instance():findImageSetByName(fileName)
	if not imageset then
		GUIImagesetManager.Instance():CreateFromFile(fileName)
		imageset = GUIImagesetManager.Instance():findImageSetByName(fileName)
	end
	if not imageset then
		return { 1, 0 }, { 1, 0 }
	end
	local name = imageInfo[2]:gsub("image:", "")
	local image = imageset:GetImage(name)
	if not image then
		GUIImagesetManager.Instance():CreateFromFile(fileName)
		image = imageset:GetImage(name)
	end
	if not image then
		return { 1, 0 }, { 1, 0 }
	end
	local width = image:GetWidth()
	local height = image:GetHeight()
	if width > maxWidth then
		height = (maxWidth / width) * height
		width = maxWidth
	end
	if height > maxHeight then
		width = (maxHeight / height) * width
		height = maxHeight
	end
	return { 0, width }, { 0, height }
end

function UILib:setImageAdjustSize(window, image, maxWidth, maxHeight, scale)
	if not window then
		return
	end
	scale = scale or 1
	maxWidth = maxWidth or window:GetPixelSize().x
	maxHeight = maxHeight or window:GetPixelSize().y
	window:SetImage(image)
	local width, height = getImageSize(image, maxWidth, maxHeight)
	window:SetWidth({ width[1] * scale, width[2] * scale })
	window:SetHeight({ height[1] * scale, height[2] * scale })
end

--- 填充，图片尽量大但不超过设置大小
function UILib:getImageByName(imageName)
	local imageInfo = Lib.splitString(imageName, " ")
	if #imageInfo ~= 2 then
		return { 1, 0 }, { 1, 0 }
	end
	local fileName = imageInfo[1]:gsub("set:", "")
	local imageset = GUIImagesetManager.Instance():findImageSetByName(fileName)
	if not imageset then
		GUIImagesetManager.Instance():CreateFromFile(fileName)
		imageset = GUIImagesetManager.Instance():findImageSetByName(fileName)
	end
	if not imageset then
		return { 1, 0 }, { 1, 0 }
	end
	local name = imageInfo[2]:gsub("image:", "")
	local image = imageset:GetImage(name)
	if not image then
		GUIImagesetManager.Instance():CreateFromFile(fileName)
		image = imageset:GetImage(name)
	end

	return image
end

local function getImageFillingSize(imageName, maxWidth, maxHeight)
	local image = UILib:getImageByName(imageName)
	if not image then
		return { 1, 0 }, { 1, 0 }
	end
	local width = image:GetWidth()
	local height = image:GetHeight()

	if width/height > maxWidth/maxHeight then
		height = (maxWidth / width) * height
		width = maxWidth
	else
		width = (maxHeight / height) * width
		height = maxHeight
	end
	return { 0, width }, { 0, height }
end

--- 填充，图片尽量大但不超过设置大小
function UILib:setImageFillingSize(window, image, maxWidth, maxHeight)
	if not window then
		return
	end
	maxWidth = maxWidth or window:GetPixelSize().x
	maxHeight = maxHeight or window:GetPixelSize().y
	window:SetImage(image)
	local width, height = getImageFillingSize(image, maxWidth, maxHeight)
	window:SetWidth({ width[1], width[2] })
	window:SetHeight({ height[1], height[2]  })
end
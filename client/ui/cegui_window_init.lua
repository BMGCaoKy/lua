local imgMgr = L("imgMgr", CEGUIImageManager:getSingleton())
---@type Quaternion
local Quaternion = require "common.math.quaternion"
---@type CEGUIWindow
local CEGUIWindow = CEGUIWindow

function CEGUIWindow:setTextAutolinefeed(text, maxLine)
    local function transform(wnd, text, Width)
        local result = ""
        local curText = ""
        local curWidth = 0
        local tbl = Lib.splitString(text, " ")
        local curLine = maxLine and 1
        for k, str in ipairs(tbl) do
            curText = curText .. str .. " "
            curWidth = wnd:getFont():getTextExtent(curText, 1.0)
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
    local area = self:getOuterRectClipper()
    local width = area.right - area.left
    if World.Lang ~= "zh_CN" then
        text = transform(self, text, width)
    end
    self:setText(text)
    return text
end

---@param self CEGUIWindow
local function setPropertyImage(self, property, imagePath, resourceGroup)
    if not imagePath or imagePath == "" then
        self:setProperty(property, imagePath)
        return
    end
    local imageset, imagePath = GUILib.getImagesetFile(imagePath)
    if not imageset and imagePath and not string.find(imagePath, "|") and not string.find(imagePath, "http://") and not string.find(imagePath, "https://") then
        imagePath = "gameres|" .. imagePath
    end
    -- todo isDefined后面用Lua表存起来查询，防止调用太多次C++函数
    local isDef = imgMgr:isDefined(imagePath)
    if imageset and not isDef then
        GUILib.loadImageset(imageset, resourceGroup)
    end
    self:setProperty(property, imagePath)
end

function CEGUIWindow:setImage(imagePath, resourceGroup)
    setPropertyImage(self, "Image", imagePath, resourceGroup)
end

function CEGUIWindow:setNormalImage(imagePath, resourceGroup)
    setPropertyImage(self, "NormalImage", imagePath, resourceGroup)
    setPropertyImage(self, "HoverImage", imagePath, resourceGroup)
end

function CEGUIWindow:setPushedImage(imagePath, resourceGroup)
    setPropertyImage(self, "PushedImage", imagePath, resourceGroup)
end

function CEGUIWindow:setDisableImage(imagePath, resourceGroup)
	setPropertyImage(self, "DisabledImage", imagePath, resourceGroup)
end

function CEGUIWindow:setText(text, showColor, textColor)
    local function getColorTextResultList(colorText, logicText)
        local function getTextItem(lColor_tab, rColor_tab, logicStr)
            --local lColorNum = lColor_tab.a << 24 | lColor_tab.r << 16 | lColor_tab.g << 8 | lColor_tab.b
            --local rColorNum = rColor_tab.a << 24 | rColor_tab.r << 16 | rColor_tab.g << 8 | rColor_tab.b
            local la = Bitwise32.Sl(lColor_tab.a, 24)
            local lr = Bitwise32.Sl(lColor_tab.r, 16)
            local lg = Bitwise32.Sl(lColor_tab.g, 8)
            local lb = lColor_tab.b

            local ra = Bitwise32.Sl(rColor_tab.a, 24)
            local rr = Bitwise32.Sl(rColor_tab.r, 16)
            local rg = Bitwise32.Sl(rColor_tab.g, 8)
            local rb = rColor_tab.b

            local lColorNum = la
            lColorNum = Bitwise32.Or(lColorNum, lr)
            lColorNum = Bitwise32.Or(lColorNum, lg)
            lColorNum = Bitwise32.Or(lColorNum, lb)

            local rColorNum = ra
            rColorNum = Bitwise32.Or(rColorNum, rr)
            rColorNum = Bitwise32.Or(rColorNum, rg)
            rColorNum = Bitwise32.Or(rColorNum, rb)

            local color1 = string.format("%8X", lColorNum)
            local color2 = string.format("%8X", rColorNum)
            if lColorNum < 0 then
                if string.len(color1) > 8 then
                    color1 = string.sub(color1, 9)
                end
            end
            if rColorNum < 0 then
                if string.len(color2) > 8 then
                    color2 = string.sub(color2, 9)
                end
            end
            return "[colourRect='tl:" .. color1 .. " tr:" .. color2 ..
                    " bl:" .. color1 .. " br:" .. color2 .. "']" .. logicStr
        end

        local function getColorTab(colorStr)
            colorStr = colorStr:sub(7, 8) .. colorStr:sub(1, 6)
            local colorNum = tonumber(colorStr, 16)
            return {
                b = Bitwise32.And(colorNum, 0xff),
                g = Bitwise32.And(Bitwise32.Sr(colorNum, 8), 0xff),
                r = Bitwise32.And(Bitwise32.Sr(colorNum, 16), 0xff),
                a = Bitwise32.And(Bitwise32.Sr(colorNum, 24), 0xff),
            }
        end

        local oldColorList = Lib.splitString(colorText, "-")
        if not oldColorList then
            return
        end
        local colorTextLen = #oldColorList
        local logicTextLen = #logicText

        if colorTextLen == 0 then
            return
        end

        if colorTextLen == 1 then
            local color1_tab = getColorTab(oldColorList[1])
            return {
                getTextItem(color1_tab, color1_tab, logicText)
            }
        end

        local offset = math.floor(logicTextLen / (colorTextLen - 1))
        local remainder = logicTextLen % (colorTextLen - 1);
        local result = {}

        local logicTextIndex = 1
        for index, color in pairs(oldColorList) do
            local interval = remainder > 0 and offset + 1 or offset
            remainder = remainder - 1
            if logicTextIndex + interval - 1 > logicTextLen then
                return result
            end

            local color1_tab = getColorTab(oldColorList[index])
            local color2_tab = getColorTab(oldColorList[index + 1])

            local lColor_tab = color1_tab
            for i = 1, interval do
                local coef = i / interval
                local rColor_tab = {
                    b = math.floor((color2_tab.b - color1_tab.b) * coef + color1_tab.b),
                    g = math.floor((color2_tab.g - color1_tab.g) * coef + color1_tab.g),
                    r = math.floor((color2_tab.r - color1_tab.r) * coef + color1_tab.r),
                    a = math.floor((color2_tab.a - color1_tab.a) * coef + color1_tab.a),
                }
                result[#result + 1] = getTextItem(
                        lColor_tab,
                        rColor_tab,
                        logicText:sub(logicTextIndex, logicTextIndex)
                )
                lColor_tab = rColor_tab
                logicTextIndex = logicTextIndex + 1
            end

        end
        return result
    end

    local function parseText(text)
        local colorList = {}
        local hasColor = false
        if not text or not text:find("&%$") then
            return text, hasColor
        end
        local newText = text:gsub("(&%$.*%$&)", function(msk)
            msk = msk:sub(3, #msk - 2)
            local result
            local splitPos = msk:find("%$")
            if splitPos <= 1 then
                return msk:sub(2)
            elseif splitPos >= #msk then
                return ""
            end

            local colorText = msk:sub(1, splitPos - 1)
            local logicText = msk:sub(splitPos + 1, #msk)
            colorText = colorText:sub(2, #colorText - 1)

            if logicText and not showColor then
                return logicText, false
            end

            result = getColorTextResultList(colorText, logicText)
            if result then
                hasColor = true
                result = table.concat(result, "") .. "[colour='" .. (textColor or "FFFFFFFF") .. "'" .. "]"
            else
                result = logicText
            end
            return result
        end)
        return newText, hasColor
    end
    if type(text) == "number" then
        text = text .. ""
    end
    local newText, hasColor = parseText(text)
    if showColor and hasColor then
        self:setProperty("TextColours", "FFFFFFFF")
    end
    self:setProperty("Text", newText)
end

function CEGUIWindow:getTextColours()
    return self:getWindowRenderer():getTextColours()
end

function CEGUIWindow:setTextColours(color)
    return self:getWindowRenderer():setTextColours(color)
end

function CEGUIWindow:getHorizontalFormatting()
    return self:getWindowRenderer():getHorizontalFormatting()
end

function CEGUIWindow:getVerticalFormatting()
    return self:getWindowRenderer():getVerticalFormatting()
end

function CEGUIWindow:setHorizontalFormatting(HorizontalTextFormatting)
    return self:getWindowRenderer():setHorizontalFormatting(HorizontalTextFormatting)
end

function CEGUIWindow:setVerticalFormatting(VerticalTextFormatting)
    return self:getWindowRenderer():setVerticalFormatting(VerticalTextFormatting)
end

function CEGUIWindow:isVerticalScrollbarEnabled()
    return self:getWindowRenderer():isVerticalScrollbarEnabled()
end

function CEGUIWindow:setVerticalScrollbarEnabled(setting)
    return self:getWindowRenderer():setVerticalScrollbarEnabled(setting)
end

function CEGUIWindow:isHorizontalScrollbarEnabled()
    return self:getWindowRenderer():isHorizontalScrollbarEnabled()
end

function CEGUIWindow:setHorizontalScrollbarEnabled(setting)
    return self:getWindowRenderer():setHorizontalScrollbarEnabled(setting)
end

function CEGUIWindow:isFrameEnabled()
    return self:getWindowRenderer():isFrameEnabled()
end

function CEGUIWindow:isBackgroundEnabled()
    return self:getWindowRenderer():isBackgroundEnabled()
end

function CEGUIWindow:setFrameEnabled(setting)
    return self:getWindowRenderer():setFrameEnabled(setting)
end

function CEGUIWindow:setBackgroundEnabled(setting)
    return self:getWindowRenderer():setBackgroundEnabled(setting)
end

function CEGUIWindow:isVertical()
    return self:getWindowRenderer():isVertical()
end

function CEGUIWindow:setVertical(setting)
    return self:getWindowRenderer():setVertical(setting)
end

function CEGUIWindow:isReversed()
    return self:getWindowRenderer():isReversed()
end

function CEGUIWindow:setReversed(setting)
    return self:getWindowRenderer():setReversed(setting)
end

function CEGUIWindow:getFillType()
    return self:getWindowRenderer():getFillType()
end

function CEGUIWindow:getFillOriginAll()
    return self:getWindowRenderer():getFillOriginAll()
end

function CEGUIWindow:getFill()
    return self:getWindowRenderer():getFill()
end

function CEGUIWindow:getAntiClockwise()
    return self:getWindowRenderer():getAntiClockwise()
end

function CEGUIWindow:setRotationX(rotationX)
    local q = Quaternion.fromEulerAngle(rotationX, 0, 0)
    local value = string.format("w:%s x:%s y:%s z:%s", q.w, q.x, q.y, q.z)
    self:setProperty("Rotation", value)
end

function CEGUIWindow:setRotationY(rotationY)
    local q = Quaternion.fromEulerAngle(0, rotationY, 0)
    local value = string.format("w:%s x:%s y:%s z:%s", q.w, q.x, q.y, q.z)
    self:setProperty("Rotation", value)
end

function CEGUIWindow:setRotationZ(rotationZ)
    local q = Quaternion.fromEulerAngle(0, 0, rotationZ)
    local value = string.format("w:%s x:%s y:%s z:%s", q.w, q.x, q.y, q.z)
    self:setProperty("Rotation", value)
end

function CEGUIWindow:getPosition()
	return UDim2.fromString(self:getProperty("Position"))
end

function CEGUIWindow:getXPosition()
	local position = self:getPosition()
	return position.x
end

function CEGUIWindow:getYPosition()
	local position = self:getPosition()
	return position.y
end

function CEGUIWindow:getSize()
	return UDim2.fromString(self:getProperty("Size"))
end

function CEGUIWindow:getWidth()
	local size = self:getSize()
	return size.width
end

function CEGUIWindow:getHeight()
	local size = self:getSize()
	return size.height
end

function CEGUIWindow:DoTween(tweenInfo, properties)
    local tween = Tween.new(UI:getWindowInstance(self), tweenInfo, properties)
    tween:Play()
	return tween
end
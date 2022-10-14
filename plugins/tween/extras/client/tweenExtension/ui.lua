---区域缓动
---@param wnd Window 窗体
---@param to player 目标位置 {x = {1, 100}, y = {1, 100}, width = {1, 100}, height = {1, 100}} 可以少传但至少保持一个
---@param duration number 缓动持续时间
---@return TweenerOperator
function UI.doTrans(wnd, to, duration)

    local getArea2Array = function (wnd, area2)
        local array = {}
        local curArea2 = UI:getArea2(wnd)
        local mapping = {"x", "y", "width", "height"}
        
        for index, prop in ipairs(curArea2) do
            array[index] = area2[index] or area2[mapping[index]] or prop
        end

        return Area2.new(array)
    end

    local getter = function()
        return Area2.new(UI:getArea2(wnd))
    end

    local setter = function(value)
        wnd:setArea2(table.unpack(value:toArray()))
    end

    local operator = Tween.tweener(getter, setter, getArea2Array(wnd, to), duration, "UIDoTrans_" .. wnd:getID())
    local oldFrom = operator.from
    operator.from = function(self, value)
        return oldFrom(self, getArea2Array(wnd, value))
    end
    operator:setVerifyHandler(function()
        local instance = UI:getWindowInstance(wnd)
        if instance then
            return instance:isAlive()
        else
            return
        end
    end)
    return operator
end

---透明度缓动
---@param wnd Window 窗体
---@param to number 目标透明度
---@param duration number 缓动持续时间
---@return TweenerOperator
function UI.doFade(wnd, to, duration)
    local getter = function()
        return wnd:getAlpha()
    end

    local setter = function(value)
        return wnd:setAlpha(value)
    end

    local operator =  Tween.tweener(getter, setter, to, duration, "UIDoFade_" .. wnd:getID())
    operator:setEase(EaseType.linear) --透明度动画默认为线性的
    operator:setVerifyHandler(function()
        local instance = UI:getWindowInstance(wnd)
        if instance then
            return instance:isAlive()
        else
            return
        end
    end)
    return operator
end

---改变窗体的尺寸。
---请注意！！！！该值是临时存储，不是永久存储
---@param wnd Window
---@param to number 整数，1为原始
---@param duration number 持续时间
function UI.doScale(wnd, to, duration)
    local scale = 1
    local s = wnd:getSize()
    local originSize = UDim2.new(s.width[1], s.width[2], s.height[1], s.height[2])

    local getter = function()
        return scale
    end

    local setter = function(value)
        scale = value
        wnd:setSize(originSize * value)
    end

    local operator =  Tween.tweener(getter, setter, to, duration, "UIDoScale_" .. wnd:getID())
    operator:setVerifyHandler(function()
        local instance = UI:getWindowInstance(wnd)
        if instance then
            return instance:isAlive()
        else
            return
        end
    end)
    return operator
end

---@private
---该接口有缺陷，请勿使用！！！
function UI.doRotate(wnd, to, duration)
    local function toVector3(wnd, to)
        if not to.x or not to.y or not to.z then
            local quaternion = Quaternion.fromString(wnd:getProperty("Rotation"))
            local curX, curY, curZ = quaternion:toEulerAngle()

            to.x = to.x or curX
            to.y = to.y or curY
            to.z = to.z or curZ
        end

        return Vector3.fromTable(to)
    end

    local getter = function()
        local quaternion = Quaternion.fromString(wnd:getProperty("Rotation"))
        return Vector3.new(quaternion:toEulerAngle())
    end

    local setter = function(value)
        local function rotationToQuaternion(v3, rotation)
            local halfRotation = 0.5 * rotation
            local halfSin = math.sin(halfRotation)
            return Quaternion.fromTable({w = math.cos(halfRotation), x = v3.x * halfSin, y = v3.y * halfSin, z = v3.z * halfSin}) 
        end

        local quaternion = rotationToQuaternion(Vector3.new(0, 0, 1), math.rad(value.z))
        wnd:setProperty("Rotation", quaternion:toString())
    end

    local operator = Tween.tweener(getter, setter, toVector3(wnd, to), duration, "UIDoRotate_" .. wnd:getID())
    local oldFrom = operator.from
    operator.from = function(self, value)
        return oldFrom(self, toVector3(wnd, value))
    end
    operator:setVerifyHandler(function()
        local instance = UI:getWindowInstance(wnd)
        if instance then
            return instance:isAlive()
        else
            return
        end
    end)
    return operator
end

---使 UI 围绕者 Z 轴旋转
---@param wnd Window
---@param to number
---@param duration number
function UI.doRotateZ(wnd, to, duration)
    local getter = function()
        local quaternion = Quaternion.fromString(wnd:getProperty("Rotation"))
        return Vector3.new(quaternion:toEulerAngle()).z
    end

    local zAxis = Vector3.new(0, 0, 1)
    local setter = function(value)
        local quaternion = Quaternion.fromRotation(zAxis, math.rad(value))
        wnd:setProperty("Rotation", quaternion:toString())
    end
    local operator = Tween.tweener(getter, setter, to, duration, "UIDoRotateZ_" .. wnd:getID())
    operator:setVerifyHandler(function()
        local instance = UI:getWindowInstance(wnd)
        if instance then
            return instance:isAlive()
        else
            return
        end
    end)
    return operator
end

---使字体连续的显示出来
---@param textWnd StaticText
---@param content string
---@param duration number
function UI.doText(textWnd, content, duration)
    local getter = function()
        local text = textWnd:getText()
        return Lib.getStringLen(text)
    end

    local setter = function(value)
        local showContent = Lib.subString(content, math.ceil(value))
        textWnd:setText(showContent)
    end

    local operator = Tween.tweener(getter, setter, Lib.getStringLen(content), duration, "UIDoText_" .. textWnd:getID())
    operator:setEase(EaseType.linear)
    operator:from(0)
    operator:setVerifyHandler(function()
        local instance = UI:getWindowInstance(textWnd)
        if instance then
            return instance:isAlive()
        else
            return
        end
    end)
    return operator
end

---使字体连续的显示出来，但是注意 duration 传入的是单个字符显示的时间
---@param textWnd StaticText
---@param content string
---@param duration number 单个字符显示的时间
function UI.doTextByLetter(textWnd, content, duration)
    return UI.doText(textWnd, content, (Lib.getStringLen(content)) * duration)
end

---传入一个表来改变一个文本窗体的字体的颜色
---@param textWnd StaticText
---@param to table<string, number>
---@param duration number
function UI.doTextColor(textWnd, to, duration)
    local operator = UI.doTextColorByColor(textWnd, Color.fromTable(to), duration)

    local oldFrom = operator.from
    function operator:from(value)
        return oldFrom(self, Color.fromTable(value))
    end
    operator:setVerifyHandler(function()
        local instance = UI:getWindowInstance(textWnd)
        if instance then
            return instance:isAlive()
        else
            return
        end
    end)
    return operator
end

---传入一个十六进制颜色来改变一个文本窗体的字体的颜色
---@param textWnd StaticText
---@param to string
---@param duration number
function UI.doTextColorByHEX(textWnd, to, duration)
    local operator = UI.doTextColorByColor(textWnd, Color.fromHEX(to), duration)

    local oldFrom = operator.from
    function operator:from(value)
        return oldFrom(self, Color.fromHEX(value))
    end
    operator:setVerifyHandler(function()
        local instance = UI:getWindowInstance(textWnd)
        if instance then
            return instance:isAlive()
        else
            return
        end
    end)
    return operator
end

---传入一个Color实例改变一个文本窗体的字体的颜色
---@param textWnd StaticText
---@param to Color
---@param duration number
function UI.doTextColorByColor(textWnd, to, duration)
    local getter = function()
        return Color.fromTable(textWnd:getTextColours())
    end

    local setter = function(value)
        textWnd:setTextColours(value)
    end

    local operator = Tween.tweener(getter, setter, to, duration, "UIDoTextColor_" .. textWnd:getID())
    operator:setEase(EaseType.linear)
    operator:setVerifyHandler(function()
        local instance = UI:getWindowInstance(textWnd)
        if instance then
            return instance:isAlive()
        else
            return
        end
    end)
    return operator
end

---传入一个进度条来改变其进度
---@param barWnd ProgressBar
---@param to number
---@param duration number
function UI.doProgress(barWnd, to, duration)
    local getter = function()
        return barWnd:getProgress()
    end

    local setter = function(value)
        barWnd:setProgress(value)
    end

    local operator = Tween.tweener(getter, setter, to, duration, "UIDoProgress_" .. barWnd:getID())
    operator:setVerifyHandler(function()
        local instance = UI:getWindowInstance(barWnd)
        if instance then
            return instance:isAlive()
        else
            return
        end
    end)
    return operator
end
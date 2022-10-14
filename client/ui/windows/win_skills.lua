
local A_Btn
local B_Btn
local worldCfg = World.cfg
local skillJack = worldCfg.skillJack or {}
local scatteredSkillsPosKey = {}

do
    for _, cfg in ipairs(skillJack.scatteredSkills or {}) do
        if cfg.posKey then
            scatteredSkillsPosKey[cfg.posKey] = true
        end
    end
end

local Grid = {}

local v_alignment = {LEFT = 0, CENTER = 1, RIGHT = 2, TOP = 0, CENTER = 1, BOTTOM = 2}
local H_alignment = {LEFT = 0, CENTER = 1, RIGHT = 2, TOP = 0, CENTER = 1, BOTTOM = 2}

local function createHolder(holder, area, hAlign, vAlign)
    local img = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Image")
    img:SetImage(holder or "")
    img:SetArea(table.unpack(area))
    img:SetVerticalAlignment(hAlign or 0)
    img:SetHorizontalAlignment(vAlign or 0)
    return img
end

local function removeHolders(arr)
    for _, image in ipairs(arr or {}) do
        local parent = image:GetParent()
        if parent then
            parent:RemoveChildWindow1(image)
        end
    end
end

local function getSkillAreaAndNames(self,equipSkills) -- 动态计算装备技能的显示位置
    local equipSkillsNames = {} -- 需要更新位置的技能
    for i, skill in pairs(equipSkills or {}) do
        equipSkillsNames[skill] = i
    end
    if next(self.sectorJacks) then
        return self.sectorJacks, equipSkillsNames
    end
    local x = A_Btn:GetXPosition()[2]
    local y = A_Btn:GetYPosition()[2]
    local w = A_Btn:GetWidth()[2]
    local h = A_Btn:GetHeight()[2]
    
    local function calculate(startAngle, endAngle, deltaAngle, count, radius, jackSize, startIndex, holder)
        local arr = UILib.autoLayoutCircle({startAngle = startAngle, endAngle = endAngle, deltaAngle = deltaAngle, count = count, radius = radius})
        for i, v in ipairs(arr) do
            local area = {{0, x - 0.5 * w + jackSize * 0.5 + v.x}, {0, y - 0.5 * h + jackSize * 0.5 + v.y}, {0, jackSize}, {0, jackSize}}
            self.sectorJacks[startIndex + i] = area
            self.sectorHolders[startIndex + i] = createHolder(holder, area, 2, 2)
        end
    end

    local index = 0
    for _, v in ipairs(skillJack.sectorSkills or {}) do
        local jackNum = v.jackNum or 2
        local jackSize = v.jackSize or 60
        local holder = v.holderImage or ""
        calculate(v.startAngle, v.endAngle, v.deltaAngle, jackNum, v.radius, jackSize, index, holder)
        index = index + jackNum
    end
    return self.sectorJacks, equipSkillsNames
end

local function createSkillGrid(self, jackSize, xOff, yOff, hAlign, vAlign)
    local grid = GUIWindowManager.instance:CreateGUIWindow1("GridView", "Grid")
    grid:SetAutoColumnCount(false)
    grid:SetMoveAble(false)
    grid:SetTouchable(false)
    grid:getContainerWindow():SetTouchable(false)
    grid:SetHorizontalAlignment(hAlign)
    grid:SetVerticalAlignment(vAlign)
    grid:SetArea({0, xOff or 0}, {0, yOff or 0}, {0, jackSize or 60}, {0, jackSize or 60})
    grid:SetLevel(0)
    self._root:AddChildWindow(grid)
    return grid
end

local function createTipView()
    local cfg = worldCfg.skillCdTip or {}
    if cfg.numSet then
        local grid = GUIWindowManager.instance:CreateGUIWindow1("GridView", "Tip")
        grid:SetArea({0,0},{0,0},{1,0},{1,0})
        grid:SetLevel(0)
        grid:SetHorizontalAlignment(1)
        grid:SetVerticalAlignment(1)
        grid:getContainerWindow():SetTouchable(false)
        grid:SetTouchable(false)
        return grid
    end
    local tip = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Tip")
    tip:SetArea({0,0},{0,0},{1,0},{1,0})
    tip:SetLevel(0)
    tip:SetTextHorzAlign(1)
    tip:SetTextVertAlign(1)
    tip:SetFontSize(cfg.font or "HT24")
    tip:SetTextColor(cfg.color or {1, 1, 1, 1})
    tip:SetVisible(false)
    return tip
end

local function updateCdTip(view, time)
    local old = view:data("time")
    if time == old then
        return
    end
    view:setData("time", time)
    local numStr = tostring(time)
    local len = string.len(numStr)
    local cfg = worldCfg.skillCdTip or {}
    local itemWidth = cfg.itemWidth or 30
    local itemHeight = cfg.itemHeight or 40
    local itemSpace = cfg.itemSpace or 3
    if not cfg.numSet then
        view:SetText(numStr)
        return
    end
    local childCount = view:GetItemCount()
    if childCount ~= len then
        view:RemoveAllItems()
        for i = 1, len do
            local item = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "image" .. i)
            item:SetArea({0, 0}, {0, 0}, {0, itemWidth}, {0, itemHeight})
            view:AddItem(item)
        end
    end
    view:InitConfig(itemSpace, 0, len)
    view:SetArea({0,0},{0,0},{0,itemWidth*len+itemSpace*(len-1)},{0,itemHeight})
    for i = 1, len do
        local num = numStr:sub(i, i)
        local image = view:GetItem(i-1)
        image:SetImage(cfg.numSet[num])
    end
end

function M:init()
    WinBase.init(self, "Skills.json", true)
    
    self.maskTimer = {}
    self.skillList = {}
    self.lineHolders = {}
    self.sectorJacks = {}
    self.sectorHolders = {}
    self.grids = {}
    self.eventList = {}

    local controlView = UI:getWnd("actionControl")
    A_Btn = controlView:child("Main-Jump-Controls")
    B_Btn = controlView:child("Main-MoveState")

    Lib.lightSubscribeEvent("error!!!!! script_client win_skill Lib event : EVENT_SHOW_SKILL",Event.EVENT_SHOW_SKILL, function(skill, show, index)
        for i, tb in ipairs(self.skillList) do --同名或同孔，要删除
            local fullName = tb.name
            if fullName == skill.fullName or (tb.pos and tb.jack and tb.pos == skill.pos and tb.jack == skill.jack) then
                local maskTimer = self.maskTimer[fullName]
                if maskTimer then
                    maskTimer()
                    self.maskTimer[fullName] = nil
                end
                for _, event in pairs(self.eventList[fullName] or {}) do
                    if event then
                        event()
                    end
                end
                self.eventList[fullName] = nil
                GUIWindowManager.instance:DestroyGUIWindow(tb.image)
                table.remove(self.skillList, i)
            end
        end
        if show then
            self.eventList[skill.fullName] = {}
            local skillName = skill.fullName
            local area = skillJack.defaultArea or {{ 0, -50 }, { 0, -280 }, { 0, 70 }, { 0, 70 }}
            local image = self:fetchImageCell("Skill_" .. skillName,area,nil,skill:getIcon(),true,true,false,"skill:" .. skill.fullName)
            local skillMask = self:fetchImageCell("Mask".. skillName,{{0,0},{0,0},{1,0},{1,0}},nil,Skill.Cfg(skillName).maskIcon or "set:main_page.json image:skill_bg.png",false,false,true,nil)
            skillMask:SetVisible(false)
            image:AddChildWindow(skillMask)
            local cdTip = createTipView()
            image:AddChildWindow(cdTip)
            local rest = skill.cdTime and Me:checkCD(skill.cdKey)
            if skill.cdTime and rest and (skill.enableCdMask or skill.enableCdTip) then
                self:updateMask(skill.cdTime, skill.cdTime - rest, skillMask, skill.enableCdMask, skill.fullName, nil, cdTip, skill.enableCdTip)
            end

            if skill.name then
                local txt = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "")
                txt:SetArea({0, 0}, {0, 20}, {1, 0}, {0, 30})
                txt:SetVerticalAlignment(2)
                txt:SetTextVertAlign(2)
                txt:SetTextHorzAlign(1)
                txt:SetText(Lang:toText(skill.name))
                if skill.textColor then
                    txt:SetTextColor(skill.textColor)
                end
                if skill.textBorder then
                    txt:SetTextBoader(skill.textBorder)
                end
                image:AddChildWindow(txt)
            end

            local tb = {
                name = skillName,
                image = image,
                mask = skillMask,
                cdTip = cdTip,
                iconArea = skill.iconArea,
                castInterval = skill.castInterval,
                pos = skill.posKey or skill.pos,
                jack = skill.jack,
                index = skill.jack or index or 1
            }
            table.insert(self.skillList, tb)
            if not skill.isTouch then 
                local skillName = tb.name
                if skill.castClickSkill then
                    skillName = skill.castClickSkill
                end
                self:lightSubscribe("error!!!!! script_client win_skill skillName = "..skillName.." event : EventWindowClick",image, UIEvent.EventWindowClick, function()
                    Skill.Cast(skillName)
                end)
            end

            if skill.trackCamera then
                local function touchDwonFunc(window, dx, dy)
                    self.originLevel = self._root:GetLevel()
                    self._root:SetLevel(1)
                    window:setData("dx", dx)
                    window:setData("dy", dy)
                    window:setData("lv", window:GetLevel())
                    window:SetLevel(1)
                    window:SetAlpha(0)
                    local x, y, w, h = window:GetXPosition(), window:GetYPosition(), window:GetWidth(), window:GetHeight()
                    window:setData("ox", window:GetXPosition())
                    window:setData("oy", window:GetYPosition())
                    window:setData("ow", window:GetWidth())
                    window:setData("oh", window:GetHeight())
                    window:SetArea({0, x[2] + (250 - w[2]) * 0.5}, {0, y[2] + (250 - h[2]) * 0.5}, {0, 250}, {0, 250})
                    window:setData("nx", window:GetXPosition())
                    window:setData("ny", window:GetYPosition())
                    local temp = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Temp")
                    temp:SetImage(skill.pushImage or skill:getIcon())
                    temp:SetArea({0, 0}, {0, 0}, w, h)
                    temp:SetHorizontalAlignment(1)
                    temp:SetVerticalAlignment(1)
                    temp:SetTouchable(false)
                    window:AddChildWindow(temp)
                end
                local function touchMoveFunc(window, dx, dy)
                    window:SetXPosition({0, window:data("nx")[2] + dx - window:data("dx")})
                    window:SetYPosition({0, window:data("ny")[2] + dy - window:data("dy")})
                end
                local function touchUpFunc(window, dx, dy)
                    self._root:SetLevel(self.originLevel)
                    window:SetLevel(window:data("lv"))
                    window:SetArea(window:data("ox"), window:data("oy"), window:data("ow"), window:data("oh"))
                    window:RemoveChildWindow("Temp")
                    window:SetAlpha(1)
                end
                UILib.addCameraControl(image, false, touchDwonFunc, touchMoveFunc, touchUpFunc)
            end

            if skill.pushImage then
                local normalImage = skill:getIcon()
                local pushImage = ResLoader:loadImage(skill, skill.pushImage)
                self:lightSubscribe("error!!!!! script_client win_skill skillName = "..skillName.." event : EventWindowTouchDown",image, UIEvent.EventWindowTouchDown, function()
                    image:SetImage(pushImage)
                end)

                self:lightSubscribe("error!!!!! script_client win_skill skillName = "..skillName.." event : EventMotionRelease",image, UIEvent.EventMotionRelease, function()
                    image:SetImage(normalImage)
                end)

                self:lightSubscribe("error!!!!! script_client win_skill skillName = "..skillName.." event : EventWindowTouchUp",image, UIEvent.EventWindowTouchUp, function()
                    image:SetImage(normalImage)
                end)
            end

            self:lightSubscribe("error!!!!! script_client win_skill skillName = "..skillName.." event : EventWindowLongTouchStart",image, UIEvent.EventWindowLongTouchStart, function()
                local castInterval = skill.castInterval
                local stopLoop
                if castInterval and castInterval>=0 then
                    self:lightSubscribe("error!!!!! script_client win_skill skillName = "..skillName.." event : EventWindowLongTouchEnd",image, UIEvent.EventWindowLongTouchEnd, function()
                       stopLoop()
                    end)
                    self:lightSubscribe("error!!!!! script_client win_skill skillName = "..skillName.." event : EventMotionRelease",image, UIEvent.EventMotionRelease, function()
                       stopLoop()
                    end)
                    local function tick()
                         Skill.Cast(tb.name)
                         return true
                    end
                    stopLoop = World.Timer(castInterval, tick)
                end
                -----------------------------------------------------
                local skillName
                if skill.isTouch then
                    skillName = tb.name
                end
                if skill.castTouchSkill then
                    skillName = skill.castTouchSkill
                end
                if skillName then  
                    local touchSkillCfg = Skill.Cfg(skillName)
                    if touchSkillCfg.progressIcon then -- 长按技能进度条
                        if not tb.progressMask then
                            local progress = touchSkillCfg.progress or 0
                            local area = {{0, 0}, {0, 0}, {1, progress}, {1, progress}}
                            local mask = self:fetchImageCell(skillName,area,image:GetLevel() + 1,touchSkillCfg.progressIcon,false,false,false,skillName)
                            mask:SetTouchable(false)
                            mask:SetVerticalAlignment(1)
                            mask:SetHorizontalAlignment(1)
                            tb.progressMask = mask
                            image:AddChildWindow(mask)
                        end
                        self:updateMask(touchSkillCfg.touchTimeMax, 0, tb.progressMask, true, skillName, touchSkillCfg.progressShowInEnd or false, cdTip, skill.enableCdTip)
                    end
                    Skill.TouchBegin({name = skillName})
                    local function onTouchEnd()
                        local timer = self.maskTimer[skillName]
                        if timer then
                            timer()
                            self.maskTimer[skillName] = nil
                        end
                        if tb.progressMask then
                            tb.progressMask:setMask(1,0.5,0.5)
                            tb.progressMask:SetVisible(false)
                        end
                        Skill.TouchEnd()
                    end
                    self:lightSubscribe("error!!!!! script_client win_skill skillName = "..skillName.." event : EventWindowLongTouchEnd",image, UIEvent.EventWindowLongTouchEnd, function()
                        onTouchEnd()
                    end)
                    self:lightSubscribe("error!!!!! script_client win_skill skillName = "..skillName.." event : EventMotionRelease",image, UIEvent.EventMotionRelease, function()
                        onTouchEnd()
                    end)
                end
            end)

            --注册事件：多段技能中，施放技能后图标修改，不能与pushImage一起用
            local iconEvent = Lib.lightSubscribeEvent("error!!!!! script_client win_skill Lib event : EVENT_UPDATE_SKILL_ICON, skillName = ".. skillName,Event.EVENT_UPDATE_SKILL_ICON, function(newIcon, skillName)
                if skillName and skillName ~= skill.fullName then
                    return
                end
                image:SetImage(newIcon)
            end)
            table.insert(self.eventList[skill.fullName], iconEvent)
        end

        local lineSkills = {}
        local sectorSkills = {}
        local areaSkills = {}
        local scatteredSkills = {}
        local ABSkills = {}
        local defaultSkills = {}
        for _, tb in ipairs(self.skillList) do
            local pos = tb.pos
            local jack = tb.jack
            if tb.iconArea then
                table.insert(areaSkills, tb)
            elseif pos then
                if scatteredSkillsPosKey[pos] then
                    table.insert(scatteredSkills, tb)
                else
                    local list = lineSkills[pos] or {}
                    table.insert(list, tb)
                    lineSkills[pos] = list
                end
            elseif jack and (jack == "A" or jack == "B") then
                table.insert(ABSkills, tb)
            elseif skillJack.sectorSkills then
                table.insert(sectorSkills, tb)
            else
                table.insert(defaultSkills, tb)
            end
            local parent = tb.image:GetParent()
            if parent then
                parent:RemoveChildWindow1(tb.image)
            end
        end

        local function createHolders(holder, radius, count)
            local list = {}
            for i = 1, count do
                local image = createHolder(holder, {{0, 0}, {0, 0}, {0, radius or 60}, {0, radius or 60}})
                table.insert(list, image)
            end
            return list
        end

        local function fillSkills(skills, grid, jackSize, jackNum, itemSpace, holders, holderImage, reverse, verticalShow)
            removeHolders(holders)
            local size = jackNum and jackNum > 0 and jackNum or #skills
            local space = itemSpace or 30
            if verticalShow then
                grid:SetWidth({0, jackSize})
                grid:SetHeight({0, (jackSize or 60) * size + space * (size - 1)})
                grid:InitConfig(space, space, 1)
            else
                grid:SetWidth({0, (jackSize or 60) * size + space * (size - 1)})
                grid:SetHeight({0, jackSize})
                grid:InitConfig(space, space, size)
            end
            table.sort(skills, function(a, b)
                return reverse and a.index > b.index or a.index < b.index
            end)
            if jackNum and jackNum > 0 then
                local index = 1
                local function gridAddItem(i)
                    local image
                    for _, tb in ipairs(skills) do
                        if not tb.jack then
                            tb.jack = index
                            index = index + 1
                        end
                        if tb.jack == i then
                            image = tb.image
                            break
                        end
                    end
                    image = image or holders[i]
                    image:SetWidth({0, jackSize})
                    image:SetHeight({0, jackSize})
                    image:SetVerticalAlignment(0)
                    image:SetHorizontalAlignment(0)
                    grid:AddItem(image)
                end
                if reverse then
                    for i = jackNum, 1, -1 do
                        gridAddItem(i)
                    end
                else
                    for i = 1, jackNum do
                        gridAddItem(i)
                    end
                end
            else
                for _, tb in ipairs(skills) do
                    local image = tb.image
                    image:SetWidth({0, jackSize})
                    image:SetHeight({0, jackSize})
                    image:SetVerticalAlignment(0)
                    image:SetHorizontalAlignment(0)
                    grid:AddItem(image)
                end
            end
        end
        for k, v in ipairs(skillJack.lineSkills or {}) do
            local posKey = v.posKey or k
            local skills = lineSkills[posKey] or {}
            if next(skills) or (v.jackNum and v.jackNum > 0 and v.holderImage) then
                if v.jackNum and v.jackNum > 0 then
                    local holders = self.lineHolders[k] or createHolders(v.holderImage, v.jackSize, v.jackNum)
                    self.lineHolders[k] = holders
                end
                local grid = self.grids[k] or createSkillGrid(self, v.jackSize, v.xOffset, v.yOffset, v.hAlign, v.vAlign)
                self.grids[k] = grid
                fillSkills(skills, grid, v.jackSize, v.jackNum, v.itemSpace, self.lineHolders[k] or {}, v.holderImage, v.reverse, v.verticalShow)
            end
        end

        for _, tb in ipairs(areaSkills) do
            self._root:AddChildWindow(tb.image)
            self:customWindowArea(tb.image, tb.iconArea)
        end

        for _, tb in ipairs(scatteredSkills) do
            self._root:AddChildWindow(tb.image)
            for _, cfg in ipairs(skillJack.scatteredSkills) do
                if cfg.posKey == tb.pos then
                    tb.image:SetArea(table.unpack(cfg.area))
                    tb.image:SetVerticalAlignment(cfg.vAlign or 2)
                    tb.image:SetHorizontalAlignment(cfg.hAlign or 2)
                    break
                end
            end
        end

        for _, tb in ipairs(defaultSkills) do
            self._root:AddChildWindow(tb.image)
        end

        for _, tb in ipairs(ABSkills) do
            if tb.jack == "A" then
                A_Btn:SetVisible(false)
                self.btn_A = tb.image
                tb.image:SetArea(A_Btn:GetXPosition(), A_Btn:GetYPosition(), A_Btn:GetWidth(), A_Btn:GetHeight())
            else
                B_Btn:SetVisible(false)
                self.btn_B = tb.image
                tb.image:SetArea(B_Btn:GetXPosition(), B_Btn:GetYPosition(), B_Btn:GetWidth(), B_Btn:GetHeight())
            end
            self._root:AddChildWindow(tb.image)
        end

        local index = 1
        local studySkillMap = Me:data("skill").studySkillMap or {studySkills = {}, equipSkills = {}}
        local sectorJacks, equipSkillsNames = getSkillAreaAndNames(self, studySkillMap.equipSkills)
        removeHolders(self.sectorHolders)
        for i = 1, #self.sectorHolders do
            local image, jack
            for _, tb in ipairs(sectorSkills) do
                if not tb.jack then
                    tb.jack = index
                    index = index + 1
                end
                local jack = equipSkillsNames[tb.name] or tb.jack
                if jack == i then
                    image = tb.image
                    break
                end
            end
            image = image or self.sectorHolders[i]
            if sectorJacks[i] then
                image:SetArea(table.unpack(sectorJacks[i]))
            end
            self._root:AddChildWindow(image)
        end
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_skill Lib event : EVENT_SHOW_CD_MASK",Event.EVENT_SHOW_CD_MASK,function(skill)
        local tb
        local skillName = skill.name
        for _, v in ipairs(self.skillList) do
            if v.name == skillName then
                tb = v
                break
            end
        end
        if not tb then
            return
        end
        if self.maskTimer[skillName] then
            return
        end
        local skillMask = tb.mask
        local skillBeginCdTime = skill.beginTime
        local skillEndCdTime = skill.endTime
        if skillEndCdTime then
            self:updateMask(skillEndCdTime - skillBeginCdTime, 0, skillMask, skill.cdMask, skillName, nil, tb.cdTip, skill.cdTip)
        end
    end)

    Lib.lightSubscribeEvent("error!!!!! script_client win_skill Lib event : EVENT_UPDATE_SKILL_JACK_AREA",Event.EVENT_UPDATE_SKILL_JACK_AREA, function(info)
        if not info then
            return
        end
        local grid = self.grids[info.pos]
        if not grid then
            return
        end

        grid:SetArea({0, info.xOff or 0}, {0, info.yOff or 0}, grid:GetWidth(), grid:GetHeight())
        grid:SetHorizontalAlignment(info.hAlign or 1)
        grid:SetVerticalAlignment(info.vAlign or 0)
    end)
end

function M:onOpen()
    Lib.emitEvent(Event.EVENT_SHOW_SKILL, {}, false)
end

function M:customWindowArea(window, area)
    local TB, LR = area.VA or 0, area.HA or 0
    local VA = area.VAlign and v_alignment[area.VAlign] or (TB >= 0 and 0 or 2)
    local HA = area.HAlign and H_alignment[area.HAlign] or (LR >= 0 and 0 or 2)
    TB = VA == v_alignment.BOTTOM and TB > 0 and TB * -1 or TB
    LR = HA == H_alignment.RIGHT and LR > 0 and LR * -1 or LR
    if not window then
        return
    end
    window:SetVerticalAlignment(VA)
    window:SetHorizontalAlignment(HA)
    window:SetArea({ 0, LR }, { 0, TB }, { 0, area.W or area.width or 70 }, { 0, area.H or area.height or 70 })
end

function M:updateMask(cdTime, curTime, mask, enableCdMask, skillName, showInEnd, cdTip, enableCdTip)
    cdTip:SetVisible(enableCdTip or false)
    mask:SetVisible(enableCdMask or false)
    local scale = (cdTime - curTime) / cdTime
    local function tick()
        scale = scale - (1 / cdTime)
        if scale <= 0 then
            cdTip:SetVisible(false)
            mask:setMask(showInEnd and 0 or 1,0.5,0.5)
            mask:SetVisible(showInEnd or false)
            self.maskTimer[skillName] = nil
            return false
        end
        updateCdTip(cdTip, math.ceil(scale * cdTime / 20))
        mask:setMask(scale,0.5,0.5)
        return true
    end
    self.maskTimer[skillName] = World.Timer(1, tick)
end

function M:fetchImageCell(imageName, areaTable, level, imagePath, visable, enableLongTouch, alwaysOnTop, name)
    local image = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", imageName)
    image:SetVerticalAlignment(2)
    image:SetHorizontalAlignment(2)
    image:SetArea(areaTable[1], areaTable[2], areaTable[3], areaTable[4])
    if level then
        image:SetLevel(level)
    end
    image:SetImage(imagePath or "")
    image:SetVisible(visable or false)
    image:setEnableLongTouch(enableLongTouch or false)
    image:SetAlwaysOnTop(alwaysOnTop or false)
    if worldCfg.skillImageMaterial then
        image:setMaterial(worldCfg.skillImageMaterial)
    end
    if name then
        image:SetName(name)
    end
    return image
end
function M:getBtnA()
    return self.btn_A or A_Btn
end
function M:getBtnB()
    return self.btn_B or B_Btn
end
return M
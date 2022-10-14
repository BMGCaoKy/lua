local M = UI:getWnd("playerinfo")
if not M then
    return
end
local health = M:child("PlayerInfo-Bottom-Health-Apple")
local healthValue = M:child("PlayerInfo-Bottom-Health-Value-Apple")
local healthText = M:child("PlayerInfo-Bottom-Health-Text-Apple")
local armorMask = M:child("PlayerInfo-Armor_Mask")
armorMask:SetVisible(false)

local BUFF_INIT_INTERVAL = 2
local BUFF_MAX_SLOT = 500
local BUFF_CLAC_SLOT = 5

local BUFF_ICON_SIZE = 47

local buffGroup = 0
local local_saveBuff_size = 0

M.showBuffIcon:InitConfig(BUFF_INIT_INTERVAL, BUFF_INIT_INTERVAL, BUFF_MAX_SLOT)

local function updateBuffGroup(add)
    buffGroup = buffGroup + add
    if BUFF_CLAC_SLOT * buffGroup >= local_saveBuff_size then
        buffGroup = 0
    end
    if buffGroup < 0 then
        buffGroup = 0
    end
end

local function updateLocalSaveBuffSize(saveBuffSize)
    local_saveBuff_size = saveBuffSize
    if local_saveBuff_size <= BUFF_CLAC_SLOT then
        armorMask:SetVisible(false)
    else
        armorMask:SetVisible(true)
    end
end

local function showBuffIconFunc(self, saveBuff)
    for i = 1, #saveBuff do
        self.showBuffIcon:AddItem(saveBuff[i].buffIcon)
    end
    updateLocalSaveBuffSize(#saveBuff)
end

local showBuffIcon2 = M:child("PlayerInfo-Armor_Click")
-- M:subscribe(showBuffIcon2, UIEvent.EventWindowClick, function()
--     updateBuffGroup(1)
--     M.showBuffIcon:SetOffset(BUFF_CLAC_SLOT * buffGroup * (-BUFF_ICON_SIZE - BUFF_INIT_INTERVAL), 0)
-- end)

local ti = TouchManager:Instance()
local downSPos
M:subscribe(showBuffIcon2, UIEvent.EventWindowTouchDown, function()
    local touch = ti:getTouch(ti:getActiveTouch())
    if not touch then
        return
    end
    downSPos = touch:getTouchPoint()
end)

M:subscribe(showBuffIcon2, UIEvent.EventWindowTouchUp, function()
    local touch = ti:getTouch(ti:getActiveTouch())
    if not touch or not downSPos then
        return
    end
    updateBuffGroup((touch:getTouchPoint().x > downSPos.x) and -1 or 1)
    M.showBuffIcon:SetOffset(BUFF_CLAC_SLOT * buffGroup * (-BUFF_ICON_SIZE - BUFF_INIT_INTERVAL), 0)
    downSPos = nil
end)

M:subscribe(showBuffIcon2, UIEvent.EventMotionRelease, function()
    local touch = ti:getTouch(ti:getActiveTouch())
    if not touch or not downSPos then
        return
    end
    updateBuffGroup((touch:getTouchPoint().x > downSPos.x) and -1 or 1)
    M.showBuffIcon:SetOffset(BUFF_CLAC_SLOT * buffGroup * (-BUFF_ICON_SIZE - BUFF_INIT_INTERVAL), 0)
    downSPos = nil
end)


local timeLeft = 0
local function setExtraHp(extraHp, extraHpLeft, time, flashBeforeMissing)
    M.extraHp =  extraHp or M.extraHp
    timeLeft = time or timeLeft
    if not extraHpLeft or extraHpLeft <= 0 or (time and time <= 0) then
        health:SetVisible(false)
        timeLeft = 0
        if M.goldAppleTimer then
            M.goldAppleTimer()
        end
        return
    end

    health:SetVisible(true)
    healthValue:SetProgress(extraHpLeft / M.extraHp)
    healthText:SetText(string.format("%.0f/%.0f", extraHpLeft, M.extraHp))
    
    if time then
        if M.goldAppleTimer then
            M.goldAppleTimer()
        end
        local temp = 1
        M.goldAppleTimer = World.Timer(5, function()
            temp = temp + 1
            timeLeft = timeLeft - 5
            if timeLeft <= flashBeforeMissing then
                health:SetVisible(temp % 2 == 0)
            end
            return timeLeft > 0
        end)
    end
end

Lib.subscribeEvent(Event.EVENT_SET_GOLD_APPLE_HP, function(packet)
    setExtraHp(packet.extraHp, packet.extraHpLeft, packet.time, packet.flashBeforeMissing)
end)

-------------------------------------------------- 护盾 相关 ↓
function SceneUIManager.GetEntityHeadUI(objID)
    local key = "*head_" .. objID
    return UI._windows[key]
end

local function bcUpdateEntityHeadUI(updateStatus, params)
    Me:sendPacket({
        pid = "BCUpdateEntityHeadUI",
        objID = Me.objID,
        updateStatus = updateStatus,
        params = params
    })
end

local healthTS = M:child("PlayerInfo-Bottom-Health-Value_TS")
local healthTest = M:child("PlayerInfo-Bottom-Health-Text")
local healthTestTS = M:child("PlayerInfo-Bottom-Health-Text_TS")
local function updateTemporaryShield(obj, equipTrays)
    if obj.isPlayer and (obj:prop("hide") or 0) > 0 then 
        bcUpdateEntityHeadUI("remove")
        return
    end
    local lastMaxTs, lastCurTs = obj.lastMaxTs or 0, obj.lastCurTs or 0
    local equips = {}
    for _, trayTb in pairs(equipTrays) do
        local item = obj:tray():fetch_tray(trayTb.tid):fetch_item_generator(1)
        if item then
            equips[#equips + 1] = item
        end
    end
    local handItem = obj:getHandItem()
    if handItem and not handItem:null() and handItem._type and handItem._type == Define.ITEM_OBJ_TYPE_SETTLED then
        local item = obj:tray():fetch_tray(handItem:tid()):fetch_item_generator(handItem:slot())
        if item and item:cfg().base ~= "equip_base" then
            equips[#equips + 1] = item
        end
    end
    local maxTS = 0
    local curTs = 0
    for i, item in pairs(equips) do
        local iets = item and not item:null() and item:cfg().equipTemporaryShield or -1
        if iets and iets > 0 then
            maxTS = maxTS + iets
            curTs = curTs + math.max(item:getVar("equipTemporaryShield") or 0, 0)
        end
    end
    if lastMaxTs == maxTS and lastCurTs == curTs then
        return
    end
    curTs = math.ceil(curTs)
    obj.lastMaxTs = maxTS
    obj.lastCurTs = curTs
    local params = nil
    if not SceneUIManager.GetEntityHeadUI(obj.objID) then
        params = {uiCfg = {name = "temporaryShield", width = 2, height = 5}, openParams = {area = {{0,23},{0,1},{0,-26},{0,10}}}}
        SceneUIManager.AddEntityHeadUI(obj.objID, params)
        bcUpdateEntityHeadUI("add", params)
    end
    if curTs <= 0 then
        healthTest:SetVisible(true)
        healthTS:SetVisible(false)
        healthTestTS:SetVisible(false)
        if maxTS == 0 then
            SceneUIManager.RemoveEntityHeadUI(obj.objID)
            bcUpdateEntityHeadUI("remove")
        else
            params = {area = {{0,23},{0,1},{0,-26},{0,10}}}
            SceneUIManager.RefreshEntityHeadUI(obj.objID, params)
            bcUpdateEntityHeadUI("ref", params)
        end
        SceneUIManager.RemoveEntityHeadUI(obj.objID)
        return
    end
    local maxHp = obj:prop("maxHp")
    healthTest:SetVisible(false)
    healthTS:SetVisible(true)
    healthTestTS:SetVisible(true)
    local width = healthTS:GetParent():GetPixelSize().x
    healthTS:SetArea({0,34},{0,0},{0,(width - 36) * math.min(curTs, maxHp) / maxHp},{0,16})
    healthTestTS:SetText(string.format("%s / %s",  curTs, maxTS))
    
    params = {area = {{0,23},{0,1},{curTs/maxTS,-26},{0,10}}}
    SceneUIManager.RefreshEntityHeadUI(Me.objID, params)
    bcUpdateEntityHeadUI("ref", params)
end

Lib.subscribeEvent(Event.EVENT_HAND_ITEM_CHANGE, function()
    World.Timer(1, Lib.emitEvent(Event.CLAC_TEMPORARY_SHIELD, Me.objID))
end)

Lib.subscribeEvent(Event.CLAC_TEMPORARY_SHIELD, function(objId)
    local obj = World.CurWorld:getObject(objId)
    if not obj or not obj:isValid() then
        return false
    end
    local equipTrays = {}
    for _, tpy in pairs(obj:cfg().equipTrays or {}) do
        local trays = obj:tray():query_trays(tpy)
        for _, trayTb in pairs(trays or {}) do
            equipTrays[#equipTrays + 1] = {tray = trayTb.tray, tid = trayTb.tid}
        end
    end
    updateTemporaryShield(obj, equipTrays)
end)
-------------------------------------------------- 护盾 相关 ↑

-------------------------------------------------- init&BUffIcon 相关 ↓
local saveBuff = {}
local customizeAreaBuff = {}
local countDownBuff = {}

local v_alignment = {LEFT = 0, CENTER = 1, RIGHT = 2, TOP = 0, CENTER = 1, BOTTOM = 2}
local H_alignment = {LEFT = 0, CENTER = 1, RIGHT = 2, TOP = 0, CENTER = 1, BOTTOM = 2}
local function customWindowArea(cell, area, progress)
    local progress = progress or 0
    if not cell or not area then
        return
    end
    local TB, LR = area.VA or 0, area.HA or 0
    local VA = area.VAlign and v_alignment[area.VAlign] or (TB >= 0 and 0 or 2)
    local HA = area.HAlign and H_alignment[area.HAlign] or (LR >= 0 and 0 or 2)
    TB = VA == v_alignment.BOTTOM and TB > 0 and TB * -1 or TB
    LR = HA == H_alignment.RIGHT and LR > 0 and LR * -1 or LR
    cell:SetVerticalAlignment(VA)
    cell:SetHorizontalAlignment(HA)
    cell:SetArea({ 0, LR + progress/2}, { 0, TB + progress/2}, { 0, (area.W or area.width or 70) + progress}, { 0, (area.H or area.height or 70) +progress})
end

function M:drawBuffIcon(buff)
    if not buff.cfg["showIcon"] then
        return
    end

    local buffCfg = buff.cfg
    local function toPath(str)
        if str and (str:find("set:") or str:find("http:") or str:find("https:")) then
            return str
        end
        if str:sub(1, 1) == "/" then
            return "plugin/" .. buffCfg.plugin .. str
        elseif str:sub(1, 1) == "@" then
            return str:sub(2)
        else
            return "plugin/" .. buffCfg.plugin .. "/" .. buffCfg.modName .. "/" .. buffCfg._name .. "/" .. str
        end
    end

    local buffId = buffCfg["id"]
    if saveBuff and next(saveBuff)then
        for i,v in pairs(saveBuff)do
            if v.buffId==buffId then
                return
            end
        end
    end
    local buffIconName = buffCfg["showIcon"]
    local buffIcon = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "buffIcon" .. tostring(buffIconName))
    local iconArea = buffCfg.iconArea
    if iconArea then -- buff 如果自定义位置则需要放在根位置并且是从右下角开始计算位置(同技能图标计算一样)
        buffIcon:SetImage(toPath(buffIconName))
        customWindowArea(buffIcon, iconArea, buffCfg.progress)
        self._root:AddChildWindow(buffIcon)
        customizeAreaBuff[buffId] = buffIcon
    elseif buffCfg.countDown then 
        local item = UIMgr:new_widget("icon_count_down", buffCfg.showIconBg, toPath(buffIconName), buff.time)
        self.showBuffCountDown:AddItem(item)
        self:updateCountDown(buff.time, item)
        countDownBuff[buffId] = item
    else
        buffIcon:SetImage(toPath(buffIconName))
        buffIcon:SetArea({ 0, 0 }, { 0, 0 }, { 0, BUFF_ICON_SIZE }, { 0, BUFF_ICON_SIZE })
        saveBuff[#saveBuff + 1] ={buffId = buffId, buffIcon = buffIcon}
        showBuffIconFunc(self, saveBuff)
    end

    local time = (not buff.cfg.noMask) and buff.time
    if buffIconName and time then
        self:updateMask(time, buffIcon)
    elseif buffIconName then
        buffIcon:setMask(0)
    end
end

function M:updateCountDown(time, item)
    time = math.floor(time / 20)
    local function tick()
        if not item then
            return false
        end
        time = time - 1
        if time <= 0 then 
            self.showBuffCountDown:getContainerWindow():RemoveChildWindow1(item)
            self.showBuffCountDown:LayoutChild()
            return false
        end
        item:invoke("SETTEXT", time.."s")
        return true
    end
    item:invoke("SETTEXT", time.."s")
    World.Timer(20, tick)
end

function M:updateMask(time, buffIcon)
    local mask = 1
    local upMask = 1 / time
    local function tick()
        if not buffIcon then
            return false
        end
        mask = mask - upMask
        if mask <= 0 then
            buffIcon:setMask(0, 0.5, 0.5)
            return false
        end
        buffIcon:setMask(mask, 0.5, 0.5)
        return true
    end
    World.Timer(1, tick)
end

function M:removeBuffIcon(buff)
    local buffCfg = buff.cfg
    local buffId = buffCfg["id"]
    local buffIcon = nil
    local buffIconIndex = 1
    for i, v in ipairs(saveBuff or {}) do
        if v.buffId == buffId then
            buffIcon = v.buffIcon
			buffIconIndex = i
			break
        end
    end
    if buffIcon then
        table.remove(saveBuff, buffIconIndex)
        updateLocalSaveBuffSize(#saveBuff)
	    self.showBuffIcon:RemoveItem(buffIcon)
    end
    if customizeAreaBuff[buffId] then
        self._root:RemoveChildWindow1(customizeAreaBuff[buffId])
        customizeAreaBuff[buffId] = nil
    end
    if countDownBuff[buffId] then
        self.showBuffCountDown:getContainerWindow():RemoveChildWindow1(countDownBuff[buffId])
        countDownBuff[buffId] = nil
    end
end
-------------------------------------------------- init&BUffIcon 相关 ↑

function M:onUpdate()
    local healthValue, healthText, hpIcon
    local foodValue, foodText, foodIcon
    local exp
    self.topInfo = self:child("PlayerInfo-Top-Infos")
    self.btmInfo = self:child("PlayerInfo-Bottom-Infos")
    self.myInfo = self:child("PlayerInfo-MyInfo")
    self.topInfo:SetVisible(false)
    self.btmInfo:SetVisible(true)
    self.myInfo:SetVisible(false)
    healthValue = self:child("PlayerInfo-Bottom-Health-Value")
    healthText = self:child("PlayerInfo-Bottom-Health-Text")
    foodValue = self:child("PlayerInfo-Bottom-Food-Value")
    foodText = self:child("PlayerInfo-Bottom-Food-Text")
    hpIcon = self:child("PlayerInfo-Bottom-Health-Icon")
    foodIcon = self:child("PlayerInfo-Bottom-Food-Icon")
    exp = self:child("PlayerInfo-Bottom-Exp")
    exp:SetVisible(false)

    local function tick()
        local curHp, maxHp = math.max(0, Me.curHp), Me:prop("maxHp")
        curHp = math.ceil(curHp)
        healthValue:SetProgress(curHp / maxHp)
        healthText:SetText(string.format("%.0f/%.0f", curHp, maxHp))
        if curHp > maxHp * 0.5 then
            hpIcon:SetImage("set:body_status.json image:hp_full.png")
        elseif curHp > 0 then
            hpIcon:SetImage("set:body_status.json image:hp_half.png")
        else
            hpIcon:SetImage("set:body_status.json image:hp_empty.png")
        end
        local curVp, maxVp = math.max(0, Me.curVp), Me:prop("maxVp")
        foodValue:SetProgress(curVp / maxVp)
        foodText:SetText(string.format("%.0f/%.0f", curVp, maxVp))
        if curVp > maxVp * 0.5 then
            foodIcon:SetImage("set:body_status.json image:vp_full.png")
        elseif curVp > 0 then
            foodIcon:SetImage("set:body_status.json image:vp_half.png")
        else
            foodIcon:SetImage("set:body_status.json image:vp_empty.png")
        end
        return true
    end
    World.Timer(2, tick)
end

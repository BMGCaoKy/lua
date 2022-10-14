--新界面目标对象信息
local isOpen = false
local curTargetHeadInfo = nil
local curTargetId = nil
local curTargetInfo = nil

function M:init()
    self.objID = Me.objID
    WinBase.init(self, "NewMainTargetEntity.json",true)
    self.base = self:child("NewMainTargetEntity-Base")
    self.base:SetVisible(false)

    self.hpBar = self:child("NewMainTargetEntity-Hp_Bar")
    self.hpText = self:child("NewMainTargetEntity-HP_Text")

    self.targetText = self:child("NewMainTargetEntity-Target_Text")

    self.targetLevel = self:child("NewMainTargetEntity-Level_Text")

    self.targetImg = self:child("NewMainTargetEntity-Head_Img")

    Lib.lightSubscribeEvent("error!!!!! : win_newmaintargetinfo lib event : EVENT_SHOW_TARGET_INFO", Event.EVENT_SHOW_TARGET_INFO, function(targetInfo)
        self:updateTargetInfo(targetInfo.targetID,targetInfo.tarTargetName,targetInfo.flag,targetInfo.targetIsPlayer)
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_newmaintargetinfo lib event : EVENT_UI_NEWMAINTARGETINFO_TARGET_INFO_UPDATE", Event.EVENT_UI_NEWMAINTARGETINFO_TARGET_INFO_UPDATE, function(userId)
        if isOpen then
            local data = UserInfoCache.GetCache(userId)
            if not data then
                self.targetImg:SetImage("set:default_icon.json image:header_icon")
                return
            end
            if curTargetHeadInfo == data then -- cache
                return
            end
            curTargetHeadInfo = data
            local dataPicUrl = data.picUrl
            if dataPicUrl and #dataPicUrl > 0 then
                self.targetImg:SetImageUrl(dataPicUrl)
            else
                self.targetImg:SetImage("set:default_icon.json image:header_icon")
            end
        end
    end)
end

function M:updateTargetInfo(targetID,tarTargetName,flag,targetIsPlayer)
    if self.timer then
        self.timer()
        self.timer = nil
    end
    -- 显示目标的信息
    if not flag or not targetID then
        self.base:SetVisible(false)
        isOpen = false
        return
    else
        self.base:SetVisible(true)
        isOpen = true
    end
    -- 头像
    if not curTargetId or curTargetId ~= targetID then
        curTargetId = targetID
        local target = World.CurWorld:getEntity(targetID)
        if not target then
            return
        end
        if targetIsPlayer then
            UserInfoCache.LoadCacheByUserIds({target.platformUserId}, function()
                Lib.emitEvent(Event.EVENT_UI_NEWMAINTARGETINFO_TARGET_INFO_UPDATE, target.platformUserId)	
            end)
        else
            local targetHeadImg = target:cfg().headImg
            if not targetHeadImg or curTargetHeadInfo == targetHeadImg then -- cache
                return
            end
            curTargetHeadInfo = targetHeadImg
            self.targetImg:SetImage(targetHeadImg)
        end
    end 
    -- 实时更新目标信息(血量/目标)
    local function tick()
        local target = World.CurWorld:getEntity(targetID)
        if not target or (target and target.curHp<=0) or Me.curHp <= 0 then
            isOpen = false
            self.base:SetVisible(false)
            curTargetId = nil
            curTargetHeadInfo = nil
            curTargetInfo = nil
            return false
        end
        local targetInfo = curTargetInfo
        local table = {curHp = math.max(0, target.curHp),maxHp = target:prop("maxHp"),targetName = tarTargetName,level = targetIsPlayer and target:getValue("level") or target:cfg().level}

        if not targetInfo or targetInfo ~= table then -- cache
            targetInfo = table
            curTargetInfo = table
        elseif targetInfo == table then
            return true
        end
        self:resetTargetInfo(targetInfo.curHp or targetInfo.maxHp or 0,targetInfo.maxHp or 1,targetInfo.targetName,targetInfo.level)
        self.base:SetVisible(flag)
        isOpen = flag
        return true
    end
    self.timer = World.Timer(5, tick)   
end

function M:resetTargetInfo(curHp,maxHp,targetName,level)
    self.hpBar:SetProgress(curHp/maxHp)
    self.hpText:SetText(tostring(string.format("%s/%s", math.ceil(curHp), math.ceil(maxHp))))
    self.targetText:SetText(targetName)
    self.targetLevel:SetText("Lv: " .. level)
end

function M:onOpen()
    isOpen = true
end

function M:onClose()
    isOpen = false
end

return M
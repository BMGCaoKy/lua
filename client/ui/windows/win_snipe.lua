local setting = require "common.setting"

local _snipe_switch = L("_snipe_switch", nil)
local snipe_distance = L("snipe_distance", 0)
local snipe_show = L("snipe_show", nil)
local snipe_switch_button = L("snipe_switch_button", nil)
local change_fov = L("change_fov", 0)
local fov = L("fov", 0)
local showImage = L("showImage", nil)
local openIcon = L("openIcon", nil)
local closeIcon = L("closeIcon", nil)
local snipeCfg
local originViewMode
local hideSnipeImg = L("hideSnipeImg", false)

local function checkHit(hitObj)
    local _type = hitObj._type
    local friend = hitObj.friend
    if friend or _type == "MISS" then
        snipe_show:SetEnabled(false)
    else
        snipe_show:SetEnabled(true)
    end
end

function M:init()
    WinBase.init(self, "Snipe.json")
    snipe_show = self:child("Snipe-snipe_show")
    snipe_switch_button = self:child("Snipe-snipe_switch")

    self:subscribe(snipe_switch_button, UIEvent.EventWindowTouchDown, function()
        if not _snipe_switch then
            self:openSnipe()
        else
            self:closeSnipe()
        end
    end)
    
    Lib.subscribeEvent(Event.RESET_SNIPE, function()
        self:closeSnipe()
    end)

    Lib.subscribeEvent(Event.EVENT_SHOW_RELOAD_PROGRESS, function(packet)
        if snipeCfg.exitWhenReload then
            self:closeSnipe()
            local reloadTime = packet.cfg.reloadTime or 20
            if packet.method ~= "Cancel" and reloadTime > 0 then
                snipe_switch_button:SetEnabled(false)
                if self.reloadTimer then
                    self.reloadTimer()
                    self.reloadTimer = nil
                end
                self.reloadTimer = World.Timer(reloadTime, function()
                    snipe_switch_button:SetEnabled(true)
                end)
            end
        end
    end)

    Lib.subscribeEvent(Event.CHECK_HIT, function(hitObj)
        checkHit(hitObj)
    end)
end

function M:onOpen(cfg, skill)
    if not cfg then
        self:closeSnipe()
        UI:closeWnd("snipe")
        return
    end
    local pathCfg = skill
    if type(cfg) == "string" then
        cfg = setting:fetch("snipe", cfg)
        pathCfg = cfg
    end
    snipeCfg = cfg
    self._root:SetLevel(cfg.level or 50)
    local _iconPos = cfg.iconPos
    snipe_switch_button:SetArea({ _iconPos.x, 0 }, { _iconPos.y, 0}, { 0, 50}, { 0, 50 })
    if cfg.showImage then
        showImage = ResLoader:filePathJoint(pathCfg, cfg.showImage)
    end
    if cfg.openIcon then
        openIcon = ResLoader:filePathJoint(pathCfg, cfg.openIcon)
    end
    if cfg.closeIcon then
        closeIcon = ResLoader:filePathJoint(pathCfg, cfg.closeIcon)
    end
    snipe_switch_button:SetImage(openIcon or "set:gun.json image:CancalAim")
    _snipe_switch = false
    hideSnipeImg = cfg.hideSnipeImg or false
end

function M:onClose()
    self:closeSnipe()
end

local function getFov()
    snipe_distance = snipeCfg.distance
    local temp = 0
    if snipe_distance==2 then
        temp = 0.4
    elseif snipe_distance==4 then
        temp = 0.8
    elseif snipe_distance==6 then
        temp = 1.2
    elseif snipe_distance==8 then
        temp = 1.6
    elseif snipe_distance==15 then
        temp = 2
    elseif snipe_distance > 0 and snipe_distance <= 2 then
        temp = snipe_distance
    end
    return temp
end

local function hideUIWhenopen(visible)
    local hideUICfg = Me:cfg().hideUIWhenOpenAim
    if not hideUICfg then
        return
    end
    local wndName = hideUICfg.windowName
    if not UI:isOpen(wndName) then
        return
    end
    local ui = UI:getWnd(wndName)
    for _, v in pairs(hideUICfg.widgetList or {}) do
        ui:child(v):SetVisible(visible)
    end
end

function M:openSnipe()
    Blockman.instance.gameSettings:setCameraSensitive((World.cfg.cameraSensitive or 0.5) *(World.cfg.cameraSensitiveWhenOpenAim or 1))
    if not snipeCfg.showFrontSight then
        Lib.emitEvent(Event.FRONTSIGHT_NOT_SHOW)
    end
    hideUIWhenopen(false)
    originViewMode = Blockman.instance:getCurrPersonView()
    Blockman.instance:setPersonView(snipeCfg.personView or 0)
    UI:getWnd("toolbar"):child("ToolBar-Perspece"):SetEnabled(false)
    change_fov = Blockman.instance.gameSettings:getFovSetting()
    fov = getFov()
    Blockman.instance.gameSettings:setFovSetting(change_fov - fov)

    if not hideSnipeImg then
        snipe_show:SetVisible(true)
        snipe_show:SetImage(showImage or "set:gun.json image:SniperSight")
    end
    
    snipe_switch_button:SetImage(closeIcon or "set:gun.json image:Aim")
    _snipe_switch = true
    if snipeCfg.shieldEvent then
        UILib.addCameraControl(self._root)
        self._root:SetEnabled(true)
    end
end

function M:isSnipeOpen()
    return _snipe_switch
end

function M:closeSnipe()
    Blockman.instance.gameSettings:setCameraSensitive((World.cfg.cameraSensitive or 0.5) )
    hideUIWhenopen(true)
    Lib.emitEvent(Event.FRONTSIGHT_SHOW)
    snipe_show:SetVisible(false)
    change_fov = Blockman.instance.gameSettings:getFovSetting()
    Blockman.instance.gameSettings:setFovSetting(change_fov + fov)
    fov = 0
    snipe_switch_button:SetImage(openIcon or "set:gun.json image:CancalAim")
    _snipe_switch = false
    UI:getWnd("toolbar"):child("ToolBar-Perspece"):SetEnabled(true)
    if originViewMode then
        Blockman.instance:setPersonView(originViewMode)
        originViewMode = nil
    end
    if snipeCfg.shieldEvent then
        UILib.removeCameralControl(self._root)
        self._root:SetEnabled(false)
    end
end

return M

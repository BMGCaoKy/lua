
local equipSkill
local curItem
local config

function M:init()
    WinBase.init(self, "SkillFrame.json", true)
    self.description = self:child("SkillFrame-Description")
    self.equipBtn = self:child("SkillFrame-Equip")
    self.equipTitle = self:child("SkillFrame-Equip-Title")
    self.equipTitle:SetText(Lang:toText("skill.equip"))
    self.skillBg = self:child("SkillFrame-Skill-Bg")

    self.equipItem = UIMgr:new_widget("cell")
    self.equipItem:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
    self.skillBg:AddChildWindow(self.equipItem)

    self:subscribe(self.equipBtn, UIEvent.EventButtonClick, function()
        local unlockFrame = config.unlockFrame or {}
        local var = unlockFrame.var or ""
        if curItem:var(var) then
            Lib.emitEvent(Event.EVENT_EQUIP_SKILL, equipSkill)
        else
            UI:openWnd("itemUnlock"):setItem(curItem, var)
        end
    end)
end

function M:onOpen(cell, cfg)
    local item = cell and cell:data("item")
    curItem = item
    config = cfg
    self.equipItem:setData("item", item)
    if not item then
        self._root:SetVisible(false)
        return
    end
    self._root:SetVisible(true)
    local itemCfg = item:cfg()
    local skillName =  itemCfg.studySkill
    equipSkill = Skill.Cfg(skillName)
    self.description:SetText(Lang:toText(itemCfg.itemintroduction))
    self.equipTitle:SetText(Lang:toText(item:var("unlock") and "skill.equip" or "item.unlock"))
    self:refreshItem(self.equipItem, cfg)
end

--更新每个item的信息
function M:refreshItem(cell)
    local item = cell:data("item")
    local qualityCfg = World.cfg.trayQualityFrame
    cell:invoke("RESET")
    if qualityCfg then
        cell:invoke("SELECT_TYPE", item, qualityCfg.selectType)
        cell:invoke("FRAME_IMAGE", item, qualityCfg.defaultIcon, qualityCfg.frameStretch)
        cell:invoke("FRAME_SELECT_IMAGE", item, qualityCfg.selectFrameIcon, qualityCfg.selectStretch)
    end
    
    --self:unsubscribe(cell)
    if not item or item:null() then
        return
    end
    local cfg = item:cfg()
    local quality = cfg.quality
    local qualityDiff = qualityCfg.qualityFrameDiff
    if quality and qualityDiff and qualityDiff[quality] then
        cell:invoke("FRAME_IMAGE", item, qualityDiff[quality].icon, qualityDiff[quality].stretch or qualityCfg.frameStretch)
    end
    cell:setData("sloter", item)
    cell:invoke("ITEM_SLOTER", item)
    cell:invoke("LD_BOTTOM", item, "")
    cell:invoke("TOP_TEXT", item, cfg.qualityDesc)
    -- 如果item配置里有showActor的字段 就显示actor
    if cfg.showActor then
        cell:invoke("ACTOR_ITEM", item, cfg.showActor)
    end
    local unlockFrame = config.unlockFrame or {}
    if unlockFrame.var then
        local unlock = item:var(unlockFrame.var)
        cell:invoke("SHOW_LOCKED", item, not unlock, unlockFrame.lockImage or "", unlockFrame.area)
    end
    if cfg.signIcon then
        local icon = ResLoader:loadImage(cfg, cfg.signIcon)
        cell:invoke("ITEM_SIGN", item, icon)
    end
end

return M
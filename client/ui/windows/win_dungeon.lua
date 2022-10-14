
local function createBoxCell(reward)
    local item = Item.CreateItem(reward.name, 1)
    local icon = item:icon()
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "BoxCell")
    cell:SetArea({0, 0}, {0, 0}, {0, 100}, {0, 100})
    local bg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Image")
    bg:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
    bg:SetProperty("StretchType", "NineGrid")
    bg:SetProperty("StretchOffset", "17 17 17 17")
    bg:SetImage("set:new_gui_treasurebox.json image:red_fram_bg.png")
    cell:AddChildWindow(bg)
    local box = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Image")
    box:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
    box:SetImage(icon)
    cell:AddChildWindow(box)
    return cell
end

function M:refreshItem(cell, count)
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
    cell:invoke("LD_BOTTOM", item, count or "")
    cell:invoke("TOP_TEXT", item, cfg.qualityDesc)
    cell:invoke("SHOW_EFFECT", item)
    -- 如果item配置里有showActor的字段 就显示actor
    if cfg.showActor then
        cell:invoke("ACTOR_ITEM", item, cfg.showActor)
    end
    if cfg.signIcon then
        local icon = ResLoader:loadImage(cfg, cfg.signIcon)
        cell:invoke("ITEM_SIGN", item, icon)
    end
    local starLevel = cfg.starLevel
    if starLevel then
        cell:invoke("SHOW_STAR_LEVEL", item, starLevel.level, ResLoader:loadImage(cfg, starLevel.icon), starLevel.width, starLevel.height)
    end
end

function M:init()
    WinBase.init(self, "Dungeon.json", true)
    self.bgImage = self:child("Dungeon-Content-Image")
    self.topText = self:child("Dungeon-Suggest")
    self.topText:SetText(Lang:toText("dungeon.suggested.attack"))
    self.levelText = self:child("Dungeon-Level")
    self.btmText = self:child("Dungeon-Drop")
    self.btmText:SetText(Lang:toText("dungeon.level.reward"))
    self.rewardGrid = self:child("Dungeon-Reward")
    self.rewardGrid:SetAutoColumnCount(false)
end

function M:setData(packet)
    local item = packet.data
    local fullName, chapterId, stage = item.fullName, item.chapterId, item.stage
    local cfg = Stage.GetStageCfg(fullName)
    local stageCfg = Stage.GetStageCfg(fullName, chapterId, stage)
    local count = stageCfg.reward and #stageCfg.reward or 1
    local gridViewCfg = cfg.gridViewCfg or {}
    local itemSize = gridViewCfg.itemSize or {}
    local itemWidth = itemSize[1] or 100
    local itemHeight = itemSize[2] or 100
    local itemSpace = gridViewCfg.itemSpace or 10
    local lineSpace = gridViewCfg.lineSpace or 10
    local lineSize = gridViewCfg.lineSize or 4
    local maxLines = gridViewCfg.maxLines or 3
    local lines = math.ceil(count/lineSize)
    self.rewardGrid:SetMoveAble(lines > maxLines)
    lines = lines > maxLines and maxLines or lines
    local height = itemHeight * lines + (lines - 1) * lineSpace
    self.btmText:SetYPosition({0, 0 - height - 40})
    self.rewardGrid:SetHeight({0, height})
    self.rewardGrid:InitConfig(itemSpace, lineSpace, lineSize)

    self.levelText:SetText(Lang:toText({"dungeon.level", stageCfg.level}))
    self.bgImage:SetImage(stageCfg.image and ResLoader:loadImage(cfg, stageCfg.image) or "")

    self.rewardGrid:RemoveAllItems()
    for _, reward in ipairs(stageCfg.reward or {}) do
        local item = Item.CreateItem(reward.name, 1)
        local cell = UIMgr:new_widget("cell")
        cell:setData("item", item)
        cell:SetArea({0, 0}, {0, 0}, {0, itemWidth}, {0, itemHeight})
        self:refreshItem(cell, item)
        self.rewardGrid:AddItem(cell)
    end
end

return M
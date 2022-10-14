
local curItem
local varKey

local function refreshItem(cell, item)
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
    if cfg.signIcon then
        local icon = ResLoader:loadImage(cfg, cfg.signIcon)
        cell:invoke("ITEM_SIGN", item, icon)
    end
end

local function createGridCell(cost)
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "Cell")
    cell:SetArea({0, 0}, {0, 0}, {0, 160}, {1, 0})
    local iconImg
    local curCount = 0
    local itemName
    if cost.typ == "Coin" then
        iconImg = Coin:iconByCoinName(cost.name)
        itemName = cost.name
        local wallet = Me:data("wallet")
        curCount = wallet[cost.name].count or 0
        local imageBg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Image")
        imageBg:SetArea({0, 0}, {0, 10}, {0, 120}, {0, 120})
        imageBg:SetHorizontalAlignment(1)
        imageBg:SetImage("set:backpack_display.json image:frame_bg.png")
        cell:AddChildWindow(imageBg)
        local image = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Image")
        image:SetArea({0, 0}, {0, 0}, {0, 80}, {0, 80})
        image:SetHorizontalAlignment(1)
        image:SetVerticalAlignment(1)
        image:SetImage(iconImg)
        imageBg:AddChildWindow(image)
    elseif cost.typ == "Item" then
        local item = Item.CreateItem(cost.name, 1)
        itemName = item:cfg().itemname or item:cfg().name or cost.name
        iconImg = item:icon()
        curCount = Me:tray():find_item_count(cost.name)
        local temp = UIMgr:new_widget("cell")
        temp:SetArea({0, 0}, {0, 10}, {0, 120}, {0, 120})
        temp:SetHorizontalAlignment(1)
        refreshItem(temp, item)
        cell:AddChildWindow(temp)
    end
    
    local name = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Name")
    name:SetArea({0, 0}, {0, 140}, {1, -20}, {0, 30})
    name:SetTextHorzAlign(1)
    name:SetTextVertAlign(1)
    name:SetHorizontalAlignment(1)
    name:SetTextBoader({119/255, 30/255, 21/255, 1})
    name:SetText(Lang:toText(itemName))
    cell:AddChildWindow(name)

    local countContent = GUIWindowManager.instance:CreateGUIWindow1("Layout", "countContent")
    countContent:SetHorizontalAlignment(1)
    cell:AddChildWindow(countContent)

    local countLb = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Count")
    countLb:SetText(curCount)
    countLb:SetFontSize("HT18")
    if curCount >= cost.count then
        countLb:SetTextColor({13/255, 255/255, 0/255, 1})
        countLb:SetTextBoader({12/255, 37/255, 13/255, 1})
    else
        countLb:SetTextColor({1, 1, 1, 1})
        countLb:SetTextBoader({1, 0, 0, 1})
    end
    countLb:SetTextVertAlign(0)
    local countLenght = countLb:GetFont():GetTextExtent(curCount, 1.0)
    countLb:SetArea({0, 0}, {0, 0}, {0, countLenght}, {1, 0})
    countContent:AddChildWindow(countLb)

    local totalCount = "/" .. cost.count
    local totalCountLb = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "TotalCount")
    totalCountLb:SetText(totalCount)
    totalCountLb:SetFontSize("HT18")
    totalCountLb:SetTextColor({1, 1, 1, 1})
    totalCountLb:SetTextBoader({119/255, 30/255, 21/255, 1})
    totalCountLb:SetTextVertAlign(0)
    local totalCountLenght = totalCountLb:GetFont():GetTextExtent(totalCount, 1.0)
    totalCountLb:SetArea({0, countLenght + 3}, {0, 0}, {0, totalCountLenght}, {1, 0})
    countContent:AddChildWindow(totalCountLb)
    countContent:SetArea({0, 0}, {0, 180}, {0, countLenght + totalCountLenght + 3}, {0, 40})
    return cell
end

local function fillGridView(self, arr)
    self.gridView:RemoveAllItems()
    if not arr then
        return
    end
    self.gridView:InitConfig(40, 0, #arr)
    for _, v in ipairs(arr) do
        local cell = createGridCell(v)
        self.gridView:AddItem(cell)
    end
end

function M:init()
    WinBase.init(self, "ItemUnlock.json", true)
    self.titleLb = self:child("ItemUnlock-Title")
    self.titleLb:SetText(Lang:toText("item.unlock.title"))
    self.closeBtn = self:child("ItemUnlock-Close")
    self.gridView = self:child("ItemUnlock-Grid")
    self.unlockTitle = self:child("ItemUnlock-Btn-Text")
    self.unlockTitle:SetText(Lang:toText("item.unlock.button"))
    self.unlockBtn = self:child("ItemUnlock-Btn")

    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)
    self:subscribe(self.unlockBtn, UIEvent.EventButtonClick, function()
        local tid, slot = curItem._tid, curItem._slot
        Me:sendPacket({pid = "ItemUnlock", tray = tid, slot = slot, varKey = varKey}, function(success, msg, name)
            if success then
                UI:closeWnd(self)
            else
                Client.ShowTip(2, msg, 20, nil, nil, {Lang:toText(name)})
            end
        end)
    end)
end

function M:setItem(item, var)
    curItem = item
    varKey = var
    local cfg = item:cfg()
    fillGridView(self, cfg.unlockCost)
end

return M
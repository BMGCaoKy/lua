
local cells = {}
local sortGist

local function createCostGridCell(cost)
    local iconImg
    if cost.typ == "Coin" then
        iconImg = Coin:iconByCoinName(cost.name)
    elseif cost.typ == "Item" then
        local item = Item.CreateItem(cost.name, 1)
        iconImg = item:icon()
    end
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "Cell")
    local equipImg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Equip")
    equipImg:SetArea({0, 0}, {0, 0}, {0, 40}, {0, 40})
    equipImg:SetImage(iconImg)
    cell:AddChildWindow(equipImg)
    local count = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Count")
    count:SetArea({0, 50}, {0, 0}, {1, -50}, {1, 0})
    count:SetText(cost.count or 1)
    count:SetTextColor({1, 1, 1, 1})
    count:SetTextBoader({119/255, 30/255, 21/255, 1})
    count:SetFontSize("HT18")
    count:SetTextHorzAlign(0)
    count:SetTextVertAlign(1)
    cell:AddChildWindow(count)
    return cell
end

local function createPropGridCell(itemCfg, prop, curBuff, nextBuff)
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "Cell")
    cell:SetArea({0, 0}, {0, 0}, {0, 180}, {1, 0})
    local titleContent = GUIWindowManager.instance:CreateGUIWindow1("Layout", "TitleContent")
    titleContent:SetHorizontalAlignment(1)
    cell:AddChildWindow(titleContent)

    local titleImg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "TitleImage")
    titleImg:SetArea({0, 0}, {0, 0}, {0, 32}, {0, 32})
    titleImg:SetVerticalAlignment(1)
    titleImg:SetImage(ResLoader:loadImage(itemCfg, prop.icon))
    titleContent:AddChildWindow(titleImg)

    local titleName = Lang:toText(prop.langKey)
    local titleLb = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Title")
    titleLb:SetText(titleName)
    titleLb:SetFontSize("HT18")
    titleLb:SetTextColor({255/255, 233/255, 186/255, 255/255})
    titleLb:SetTextBoader({119/255, 30/255, 21/255, 255/255})
    titleLb:SetTextVertAlign(0)
    local titleLenght = titleLb:GetFont():GetTextExtent(titleName, 1.0)
    titleLb:SetArea({0, 35}, {0, 3}, {0,titleLenght}, {0, 32})
    titleContent:AddChildWindow(titleLb)
    titleContent:SetArea({0, 0}, {0, 0}, {0, 35 + titleLenght}, {0.5, 0})

    local propContent = GUIWindowManager.instance:CreateGUIWindow1("Layout", "PropContent")
    propContent:SetHorizontalAlignment(1)
    cell:AddChildWindow(propContent)

    local gainKey = prop.gainKey
    local curAddProp = curBuff[gainKey] or 0
    local propValue = prop.value + curAddProp
    local propLb = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Prop")
    propLb:SetText(propValue)
    propLb:SetFontSize("HT18")
    propLb:SetTextColor({1, 1, 1, 1})
    propLb:SetTextBoader({119/255, 30/255, 21/255, 1})
    propLb:SetTextVertAlign(0)
    local propLenght = propLb:GetFont():GetTextExtent(propValue, 1.0)
    propLb:SetArea({0, 0}, {0, 0}, {0, propLenght}, {1, 0})
    propContent:AddChildWindow(propLb)

    local nextAddProp = nextBuff[gainKey] and ("+" .. (nextBuff[gainKey] - curAddProp)) or ""
    local addPropLb = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "AddProp")
    addPropLb:SetText(nextAddProp)
    addPropLb:SetFontSize("HT18")
    addPropLb:SetTextColor({13/255, 255/255, 0/255, 1})
    addPropLb:SetTextBoader({12/255, 37/255, 13/255, 1})
    addPropLb:SetTextVertAlign(0)
    local addPropLenght = addPropLb:GetFont():GetTextExtent(nextAddProp, 1.0)
    addPropLb:SetArea({0, propLenght + 3}, {0, 0}, {0, addPropLenght}, {1, 0})
    propContent:AddChildWindow(addPropLb)
    propContent:SetArea({0, 0}, {0.5, 0}, {0, propLenght + addPropLenght + 3}, {0.5, 0})
    return cell
end

--背包过滤
local function filterTray(filterKey, trayType)
    local curTrays = {}
    local trayArray = Me:tray():query_trays(trayType)
    for _, element in pairs(trayArray) do
        local tray = element.tray
        local items = tray and tray:query_items(function(item)
            if filterKey and item:cfg()[filterKey] then
                return true
            end
            return false
        end)
        for _, item in pairs(items) do
            table.insert(curTrays, item)
        end
    end
    --排序依据，不知道写哪里，先写死按品质排序
    if sortGist then
        table.sort(curTrays, function(item1, item2)
            local type1 = Me:tray():fetch_tray(item1:tid()):type()
            local type2 = Me:tray():fetch_tray(item2:tid()):type()
            if type1 ~= type2 then
                if Define.TRAY_TYPE_CLASS[type1] ~= Define.TRAY_TYPE_CLASS[type2] then
                    return Define.TRAY_TYPE_CLASS[type1] == Define.TRAY_CLASS_EQUIP and Define.TRAY_TYPE_CLASS[type2] ~= Define.TRAY_CLASS_EQUIP
                end
            end
            local gist_1, gist_2 = item1:cfg()[sortGist], item2:cfg()[sortGist]
            if gist_1 and gist_2 then
                return gist_1 > gist_2
            end
            return false
        end)
    end
    return curTrays
end

local function showTip(self, tip, time)
    self.tip:SetText(Lang:toText(tip))
    World.Timer(time, function()
        self.tip:SetText("")
        return false
    end)
end

function M:init()
    WinBase.init(self, "EquipUpgrade.json", true)
    self.title = self:child("EquipUpgrade-Title")
    self.tip = self:child("EquipUpgrade-Upgrade-Tip")
    self.closeBtn = self:child("EquipUpgrade-Close")
    self.leftGridContent = self:child("EquipUpgrade-Grid-Content")
    self.topCtBg = self:child("EquipUpgrade-Equip-Bg5")
    self.equipBg = self:child("EquipUpgrade-Equip-Bg7")
    self.equipPropGrid = self:child("EquipUpgrade-Prop-Grid")
    self.equipPropGrid:SetMoveAble(false)
    self.equipName = self:child("EquipUpgrade-Equip-Name")
    self.successRateText = self:child("EquipUpgrade-Equip-Rate")
    self.successRateVl = self:child("EquipUpgrade-Equip-Rate-Num")
    self.maxLvText = self:child("EquipUpgrade-Equip-Rate-1")
    self.maxLvVl = self:child("EquipUpgrade-Equip-Sp-Vl-L-1")
    self.curLvVl = self:child("EquipUpgrade-Equip-Rate-Num-1")
    self.upgradeBtn = self:child("EquipUpgrade-Upgrade-Btn")
    self.upgradeText = self:child("EquipUpgrade-Upgrade-Text")
    self.costGrid = self:child("EquipUpgrade-Cost-Grid")
    self.costGrid:SetAutoColumnCount(false)
    self.costGrid:SetMoveAble(false)

    self.title:SetText(Lang:toText("equip.upgrade"))
    self.successRateText:SetText(Lang:toText("equip.upgrade.rate"))
    self.maxLvText:SetText(Lang:toText("equip.upgrade.max"))

    local h = self.topCtBg:GetPixelSize().y
    self.topCtBg:SetWidth({0, h * 255 / 120})
    self.slotIndex = 1
    self.gridView = UIMgr:new_widget("grid_view")
    self.gridView:invoke("AUTO_COLUMN", false)
    self.gridView:invoke("INIT_CONFIG", 0, 17, 1)
    self.gridView:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
    self.leftGridContent:AddChildWindow(self.gridView)
    
    self.equipItem = UIMgr:new_widget("cell")
    local lb = self.equipItem:child("widget_cell-lb_bottom")
    lb:SetFontSize("HT24")
    lb:SetTextVertAlign(2)
    lb:SetTextHorzAlign(2)
    lb:SetArea({0, -10}, {0, -3}, {0, 50}, {0, 50})
    self.equipItem:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
    self.equipBg:AddChildWindow(self.equipItem)

    self.effectView = GUIWindowManager.instance:CreateGUIWindow1("Layout", "Effect")
    self.effectView:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
    self.equipBg:AddChildWindow(self.effectView)

    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)
    self:subscribe(self.upgradeBtn, UIEvent.EventButtonClick, function()
        if self.timer then
            return
        end
        self.timer = World.Timer(40, function()
            self.timer = nil
            return false
        end)
        local cell = cells[self.slotIndex]
        local item = cell:data("item")
        local tid, slot = item._tid, item._slot
        Me:itemUpgrade(tid, slot, function(success, msg, name)
            local item = Me:tray():fetch_tray(tid):fetch_item_generator(slot)
            local cfg = item:cfg()
            if success then
                cell:setData("item", item)
                self:initDesc(item)
                self:refreshItem(cell)
                self.effectView:SetEffectName(cfg.upgradeEffect or "")
                self.effectView:PlayEffect(cfg.upgradeEffectTime or 20)
                showTip(self, "item_upgrade_success", 40)
                return
            end
            if msg == "upgrade_fail" then
                self.effectView:SetEffectName(cfg.upgradeFailEffect or "")
                self.effectView:PlayEffect(cfg.upgradeFailEffectTime or 20)
                showTip(self, "item_upgrade_fail", 40)
            elseif msg == "coin_not_enough" then
                --现金不足
                showTip(self, {msg, Lang:toText(name)}, 40)
            elseif msg == "item_not_enough" then
                --材料不足
                showTip(self, {msg, Lang:toText(name)}, 40)
            elseif msg == "max_level" then
                --已是最高等级
            else
                --未知错误
            end
        end)--todo
    end)
end

function M:onOpen(packet)
	self:resetSelectClick(true)
    local control = UI:getWnd("actionControl", true)
    if control and control.onDragTouchUp then
        control:onDragTouchUp()
    end
    self.slotIndex = 1
    sortGist = packet.sortGist
    local items = filterTray("canUpgrade", function()
        return true
    end)
    self:showContent(items)
end

function M:onClose()
    cells = {}
    self.slotIndex = 1
    self.gridView:invoke("CLEAN")
    self.listLoadTimer = self.listLoadTimer and self.listLoadTimer() and nil
	self:resetSelectClick(false)
	self.selectCell = nil
end

function M:updateCells()
    
end

--主内容显示
function M:showContent(items)
    local idx = 1
    self.listLoadTimer = World.Timer(1,function()
        if idx > #items then
            return false
        end
        local index = idx
        local item = items[index]
        local cell = UIMgr:new_widget("cell")
		cell:SetName("cell-"..item:full_name())
        cell:setData("item", item)
        cell:invoke("FRAME_SIZE", item, 145, 145)
        local lb = cell:child("widget_cell-lb_bottom")
        lb:SetFontSize("HT24")
        lb:SetTextVertAlign(2)
        lb:SetTextHorzAlign(2)
        lb:SetArea({0, -10}, {0, -3}, {0, 50}, {0, 50})
        self:refreshItem(cell)
        if index == self.slotIndex then
            self:resetCell(cell)
            self:initDesc(item)
        end
        cells[index] = cell
        self.gridView:invoke("ITEM", cell)
        self:subscribe(cell, UIEvent.EventWindowClick, function()
            self.slotIndex = index
            self:resetCell(cell)
            self:initDesc(item)
        end)
        idx = idx + 1
        return true
    end)

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
    local curLv = item:getValue("curLevel")
    local upLv = curLv == 0 and "" or ("+"..curLv)
    cell:invoke("LD_BOTTOM", item, upLv)
    cell:invoke("TOP_TEXT", item, cfg.qualityDesc)
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
    
    local pixel = cell:GetPixelSize()
    local l = math.min(pixel.x, pixel.y) - 25
    cell:invoke("SET_ITEM_AREA", {{0,0},{0,0},{0,l}, {0,l}})
end

function M:initDesc(item)
    self.equipItem:setData("item", item)
    self:refreshItem(self.equipItem)
    local tray_bag = Me:tray():fetch_tray(item._tid)
    if not tray_bag then
        return false
    end
    local itemData = tray_bag:fetch_item(item._slot)
    if not itemData then
        return false
    end
    local cfg = itemData._cfg
    local extends = cfg.extendDesc and cfg.extendDesc.value or {}
    local function extendValue(index)
        return extends[index] and extends[index].value or 0
    end

    local baseBuffName = cfg.equip_buff
    local curLv = item:getValue("curLevel")
    local nextLvCfg = itemData:levelCfg(curLv + 1) or {}
    local curLvBuffName = itemData:equip_levelBuff(curLv)
    local nextLvBuffName = itemData:equip_levelBuff(curLv + 1)
    local baseBuffCfg = baseBuffName and Entity.BuffCfg(baseBuffName) or {}
    local curLvBuffCfg = curLvBuffName and Entity.BuffCfg(curLvBuffName) or {}
    local nextLvBuffCfg = nextLvBuffName and Entity.BuffCfg(nextLvBuffName) or {}
    self.equipPropGrid:RemoveAllItems()
    self.equipPropGrid:InitConfig(20, 0, #extends)
    for _, v in ipairs(extends) do
        local cell = createPropGridCell(cfg, v, curLvBuffCfg, nextLvBuffCfg)
        self.equipPropGrid:AddItem(cell)
    end

    local baseAttack = extendValue(1)
    local baseSpeed = extendValue(2)
    local equipLv = extendValue(3)
    local maxLv = itemData:maxLevel()
    
    local successRate = nextLvCfg.successRate or 1
    local successRateStr = string.format("%.1f%%", successRate * 100)

    local exAttack = (nextLvBuffCfg.damage or 0) - (curLvBuffCfg.damage or 0)
    local isMaxLv = curLv == maxLv
    local size = nextLvCfg.cost and #nextLvCfg.cost or 1
    self.costGrid:RemoveAllItems()
    self.costGrid:InitConfig(20, 0, size)
    local width = 0
    for _, cost in ipairs(nextLvCfg.cost or {}) do
        local cellWidth = #tostring(cost.count or 1) * 16 + 50
        local cell = createCostGridCell(cost)
        cell:SetArea({0, 0}, {0, 0}, {0, cellWidth}, {0, 40})
        self.costGrid:AddItem(cell)
        width = width + cellWidth
    end
    width = width + (size - 1) * 20
    self.costGrid:SetWidth({0, width})
    self.equipName:SetText(Lang:toText(cfg.itemname or ""))
    self.successRateVl:SetText(successRateStr)
    self.curLvVl:SetText(curLv)
    self.maxLvVl:SetText("/"..maxLv)
    self.upgradeText:SetText(Lang:toText(isMaxLv and "equip.level.max" or "equip.upgrade"))
end

function M:resetCell(cell)
    local curCell = self.selectCell
    self.selectCell = nil
    if curCell and curCell ~= cell and curCell:receiver() then
        curCell:receiver():onClick(false)
    end
    if cell and cell:receiver() then
        cell:receiver():onClick(true)
        self.selectCell = cell
    end
end

function M:resetSelectClick(click)
	local selectCell = self.selectCell
	if selectCell and selectCell:receiver() then
		selectCell:receiver():onClick(click)
	end
end

return M
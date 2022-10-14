local M = UI:getWnd("appMainRole")
if not M then
    return
end
M.closeBtn:SetProperty("SoundName", "70")

function M:registerSelectEvent(item, cfg, parentIndex)
    if cfg.child then
        self:subscribe(item, UIEvent.EventButtonClick, function()
            self:openChild(cfg, parentIndex, not self._tabParentChild[parentIndex], item)
        end)
    else
        self:subscribe(item, UIEvent.EventRadioStateChanged, function()
            self:selectItem(item, cfg)
        end)
    end
end

function M:setItemParent(name, cfg, parentIndex)
    local item
    if not cfg.child then
        item = GUIWindowManager.instance:CreateGUIWindow1("RadioButton", name)
        item:SetProperty("SoundName", "70")
        item:SetPushedImage("set:skill_character_system.json image:left_tab_select_1.png")
        item:SetNormalImage("set:skill_character_system.json image:left_tab_1.png")

    else
        local icoItem = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "ico")
        icoItem:SetImage("set:skill_character_system.json image:left_tab_slippery.png")
        icoItem:SetArea({0, 175}, {0, 39}, {0, 20}, {0, 12})
        item = GUIWindowManager.instance:CreateGUIWindow1("Button", name)
        item:SetPushedImage("set:skill_character_system.json image:left_tab_1.png")
        item:SetNormalImage("set:skill_character_system.json image:left_tab_1.png")
        item:AddChildWindow(icoItem)
    end
    self:registerSelectEvent(item, cfg, parentIndex)
    item:SetTextColor({255/255, 250/255, 174/255})
    item:SetText(Lang:toText(cfg.tabName))
    item:SetWidth({0, 211})
    item:SetHeight({0, 86})
    item:SetHorizontalAlignment(1)
    item:SetProperty("Font", "HT16")

    return item
end
local globalSetting = require "editor.setting.global_setting"
local entitySetting = require "editor.setting.entity_setting"
local shopSetting = require "editor.setting.shop_setting"
local entity_obj = require "editor.entity_obj"
local compositeSetting = require "editor.setting.composite_setting"

local allLabelList = {
    "playerSetting",
    "gameSetting",
    "teamSetting",
    "victorySetting",
    "shopSetting",
    "otherSetting"
}

local allLabelLang = {Lang:toText("win.map.global.playerSetting"),
                    Lang:toText("win.map.global.gameSetting"),
                    Lang:toText("win.map.global.teamSetting"),
                    Lang:toText("win.map.global.victorySetting"),
                    Lang:toText("win.map.global.shopSetting"),
                    Lang:toText("win.map.global.otherSetting")}
local labelLang = {}
local winSetting = {}
local labelName = {}
local eventTracking = {
    playerSetting = "click_global_setting_player",
    gameSetting = "click_global_setting_game_start",
    teamSetting = "click_global_setting_team_settings",
    victorySetting = "click_global_setting_rewards_victory_conditions",
    shopSetting = "click_global_setting_store_settings",
    compositeSetting = "click_global_setting_synthesis_system",
    rewardSetting = "click_global_setting_rewards",
    otherSetting = "click_global_setting_other"
}

do
    for i, v in ipairs(allLabelList) do
            local key = #labelName + 1
            labelName[key] = v
            labelLang[key] = allLabelLang[i]
    end
end

function M:init()
    WinBase.init(self, "globalSetting_edit.json")
    self:child("Global-TitleBG-Text"):SetText(Lang:toText("win.map.global.ruleSetting"))
    self.m_root = self:child("Global-root")
    self.m_back = self:child("Global-BackBtn")
    self.m_ltGrid = self:child("Global-Lt-Grid")
    self.last_selectIdx = 1
	self.maskImageList = {}

    self:initRtLayout()
    self:initLtLabel()

    self:subscribe(self.m_back, UIEvent.EventButtonClick, function()
        self:saveData()
        self:doDelShopName()
        UI:closeWnd(self)
        entity_obj:delPointEntity()
        entity_obj:buildPointEntity()
    end)
end

function M:bindWnd(key, flag)
    if self.last_selectIdx ~= key then
        if winSetting[self.last_selectIdx] then
            self.m_rtLayout:RemoveChildWindow1(winSetting[self.last_selectIdx]:root())
            local selectIdx = self.last_selectIdx
            World.Timer(2, function()
                winSetting[selectIdx]:onClose()
                return false
            end) 
        end
    end
    if winSetting[key] then
        self.m_rtLayout:AddChildWindow(winSetting[key]:root())
    else
        self:createSettingWnd(key)
    end
    winSetting[key]:onOpen(flag)
    self.last_selectIdx = key
end

function M:createSettingWnd(key)
    if not labelName[key] then
        return
    end
    local name = labelName[key]:sub(1,1):upper() .. labelName[key]:sub(2);
    local winName = string.format("mapEdit%s",name)
    winSetting[key] = UI:getWnd(winName) or nil
    if winSetting[key] then
        self.m_rtLayout:AddChildWindow(winSetting[key]:root())
    end
end

function M:initLtLabel()
    self.m_ltGrid:InitConfig(0, 3, 1)
    for key, name in ipairs(labelName) do
        local layout = GUIWindowManager.instance:CreateGUIWindow1("Layout", "img" .. key)
        layout:SetHeight({0, 78})
        layout:SetWidth({0.85, 0})
		if key ~= 1 then
			local img = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "img" .. key)
			img:SetHeight({0, 2})
			img:SetWidth({1, 0})
			img:SetImage("set:setting_global2.json image:partline.png")
			layout:AddChildWindow(img)
		end
        local btnText = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "btnText" .. key)
        btnText:SetArea({0, 0}, {0, 0}, {0, 200}, {1, 0})
        btnText:SetTextVertAlign(1)
        btnText:SetTextHorzAlign(1)
        btnText:setTextAutolinefeed(labelLang[key])
        btnText:SetWordWrap(true)
        btnText:SetTextColor({44 / 255, 177 / 255, 130 / 255,1})
        layout:AddChildWindow(btnText)
        local maskBtn = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "maskImge")
        maskBtn:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
        maskBtn:SetHeight({0, 84})
        maskBtn:SetWidth({1.025, 0})
        maskBtn:SetImage("set:setting_global2.json image:bg_global_lefttap_selected.png")
        local maskText = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "maskText")
        maskText:SetArea({0, 0}, {0, 0}, {0, 200}, {1, 0})
        maskText:SetTextVertAlign(1)
        maskText:SetTextHorzAlign(1)
        maskText:setTextAutolinefeed(labelLang[key])
        maskText:SetWordWrap(true)
        maskBtn:AddChildWindow(maskText)
        
        layout:AddChildWindow(maskBtn)
        maskBtn:SetVisible(key == 1)
        self.maskImageList[key] = {
			maskBtn = maskBtn,
			btnText = btnText
		}
        if key == 1 then
            self.lastMaskBtn = maskBtn
        end
        self:subscribe(layout, UIEvent.EventWindowTouchUp, function()
            CGame.instance:onEditorDataReport(eventTracking[name], "")
            self:bindWnd(key)
            self:setSelectMask(maskBtn)
        end)
        self.m_ltGrid:AddItem(layout)
    end
    self:bindWnd(self.last_selectIdx)
end

function M:setSelectMask(maskBtn)
    if self.lastMaskBtn then
        self.lastMaskBtn:SetVisible(false)
    end
    maskBtn:SetVisible(true)
    self.lastMaskBtn = maskBtn
end

function M:initRtLayout()
    self.m_rtLayout = self:child("Global-Rt-Layout")
end

function M:saveData()
    for k, v in pairs(winSetting) do
        winSetting[k]:saveData()
    end
    entitySetting:save("myplugin/player1")
    globalSetting:save()
    shopSetting:saveCache()
end

function M:cancelSave()
    for k, v in pairs(winSetting) do
        if winSetting[k].cancelSave then
            winSetting[k]:cancelSave()
        end
    end
end

function M:addDelShopName(shopName)
    self.delShopNameTable = self.delShopNameTable or {}
    table.insert(self.delShopNameTable,shopName)
end

function M:clearDelShopName()
    self.delShopNameTable = nil
end

function M:doDelShopName()
    if not self.delShopNameTable then
        return
    end
    self.delShopNameTable = self.delShopNameTable or {}
    for k,v in pairs(self.delShopNameTable) do
        entitySetting:delShopName(v,false)
    end
end

function M:onOpen(selectIdx, flag)
	if selectIdx then
		self:bindWnd(selectIdx, flag)
        World.Timer(1, function()
            self:setSelectMask(self.maskImageList[selectIdx].maskBtn)
            return false
        end)
	else
		if winSetting[self.last_selectIdx] then
			winSetting[self.last_selectIdx]:onOpen()
		end
    end
end

function M:onReload()

end

function M:onClose()
    if winSetting[self.last_selectIdx] then
        World.Timer(1, function()
            winSetting[self.last_selectIdx]:onClose()
            return false
        end)
    end
end

return M
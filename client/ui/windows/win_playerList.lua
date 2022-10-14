
function M:init()
    WinBase.init(self, "PlayerList.json")

	Lib.lightSubscribeEvent("error!!!!! : win_playerList lib event : EVENT_GAME_START", Event.EVENT_GAME_START, function()
        UI:closeWnd(self)
    end)

	Lib.lightSubscribeEvent("error!!!!! : win_playerList lib event : EVENT_PLAYER_LOGIN", Event.EVENT_PLAYER_LOGIN, function(player)
         if Game.IsWaitingState() then
			self:updatePlayerList(player)
		end
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_playerList lib event : EVENT_PLAYER_LOGOUT", Event.EVENT_PLAYER_LOGOUT, function(player)
         if Game.IsWaitingState() then
			self:updatePlayerList(player)
		end
    end)

    Lib.lightSubscribeEvent("error!!!!! : win_playerList lib event : EVENT_PLAYER_RECONNECT", Event.EVENT_PLAYER_RECONNECT, function()
         if Game.IsWaitingState() then
			self:updatePlayerList()
		end
    end)
end

local function fetchItem(msg, iconPath)
    local box = GUIWindowManager.instance:CreateGUIWindow1("Layout")
    box:SetHorizontalAlignment(1)
    box:SetVerticalAlignment(0)
    box:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 0, 30 })
    local text = GUIWindowManager.instance:CreateGUIWindow1("StaticText")
    text:SetTouchable(false)
    text:SetHorizontalAlignment(2)
    text:SetVerticalAlignment(1)
    text:SetTextScale(1)
    text:SetWordWrap(true)
    text:SetArea({ 0, 0 }, { 0, 0 }, { 1, -50 }, { 1, 0 })
	text:SetSelfAdaptionArea(true)
    text:SetText(msg)

    local icon = GUIWindowManager.instance:CreateGUIWindow1("StaticImage")
    icon:SetTouchable(false)
    icon:SetHorizontalAlignment(0)
    icon:SetVerticalAlignment(1)
    icon:SetArea({ 0, 10 }, { 0, 0 }, { 0, 30 }, { 0, 30 })
    icon:SetImage(iconPath or "")
    box:AddChildWindow(icon)
    box:AddChildWindow(text)
    return box
end

function M:updatePlayerList(player)
    if not self.showPlayerList then
        self:initPlayerList()
        self.showPlayerList = true
    end
    local list = self.playerListInfo
    list:ClearAllItem()
    local players = Game.GetAllPlayersInfo()
    for _, player in pairs(players) do
        list:AddItem(fetchItem(player.name, World.cfg["TEAM_INIT." .. player.teamID]), false)
    end
	local minPlayers = World.cfg.minPlayers or World.cfg.maxPlayers or 8
    self.playerListValue:SetText(Game.GetAllPlayersCount() .. "/" .. minPlayers)
end

function M:initPlayerList()
    self.playerList = self:child("Player-Player-List")
    self.playerListValue = self:child("Player-List-Title-Value")
    if World.cfg.showPlayerList ~= nil then
        self.playerList:SetVisible(World.cfg.showPlayerList)
    else
        self.playerList:SetVisible(true)
    end
    self.playerListInfo = self:child("Player-List-Info")
    self:child("Player-List-Title-Name"):SetText(Lang:toText("toolbar_player_list_title_name"))
end

return M
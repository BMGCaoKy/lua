
local gameKey
local game_list = {}
local teamGameKey
local teamListCells = {}

local function isLeader()
    local teamId = Me:getValue("teamId")
    local team = Game.GetTeam(teamId) or {}
    return team.leaderId == Me.objID
end

local function createTeamWaitCell(self)
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "TeamWaitCell")
    cell:SetArea({0, 0}, {0, 0}, {1, 0}, {0, 58})
    cell:SetBackgroundColor({0, 0, 0, 38/255})
    local wait = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Name")
    wait:SetArea({0, 10}, {0, 0}, {0, 142}, {1, 0})
    wait:SetTextHorzAlign(0)
    wait:SetTextVertAlign(1)
    wait:SetText(Lang:toText("team.wait"))
    cell:AddChildWindow(wait)
    return cell
end

local function createMemberCell(self, player, leaderId, playerInfo)
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "TeamCell")
    cell:SetArea({0, 0}, {0, 0}, {1, 0}, {0, 58})
    cell:SetBackgroundColor({0, 0, 0, 38/255})
    local name = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Name")
    name:SetArea({0, 10}, {0, 0}, {0, 142}, {1, 0})
    name:SetTextHorzAlign(0)
    name:SetTextVertAlign(1)
    name:SetTextColor({1, 228/255, 73/255, 1})
    name:SetText(player.name)
    cell:AddChildWindow(name)
    local image = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Image")
    image:SetArea({0, 182}, {0, 0}, {0, 32}, {0, 32})
    image:SetVerticalAlignment(1)
    image:SetImage("set:endless_main.json image:level_star.png")
    cell:AddChildWindow(image)
    local level = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Level")
    level:SetArea({0, 222}, {0, 0}, {0, 60}, {1, 0})
    level:SetTextHorzAlign(0)
    level:SetTextVertAlign(1)
    level:SetTextColor({1, 228/255, 73/255, 1})
    level:SetText("Lv."..playerInfo.level)
    cell:AddChildWindow(level)
    if isLeader() and player.objID ~= leaderId then
        local exitBtn = GUIWindowManager.instance:CreateGUIWindow1("Button", "ExitBtn")
        exitBtn:SetArea({0, -10}, {0, 0}, {0, 34}, {0, 34})
        exitBtn:SetVerticalAlignment(1)
        exitBtn:SetHorizontalAlignment(2)
        exitBtn:SetNormalImage("set:editor.json image:no.png")
        exitBtn:SetPushedImage("set:editor.json image:no.png")
        cell:AddChildWindow(exitBtn)
        self:subscribe(exitBtn, UIEvent.EventButtonClick, function()
            Game.RequestQuitTeamMember(Me, player.objID)
        end)
    end
    return cell
end

local function createTeamCell()
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "TeamCell")
    cell:SetArea({0, 0}, {0, 0}, {1, 0}, {0, 58})
    cell:SetBackgroundColor({0, 0, 0, 38/255})
    local name = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Name")
    name:SetArea({0, 10}, {0, 0}, {0, 142}, {1, 0})
    name:SetTextHorzAlign(0)
    name:SetTextVertAlign(1)
    name:SetTextColor({1, 228/255, 73/255, 1})
    cell:AddChildWindow(name)
    local image = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Image")
    image:SetArea({0, 178}, {0, 0}, {0, 40}, {0, 40})
    image:SetVerticalAlignment(1)
    image:SetImage("set:endless_main.json image:team_member.png")
    cell:AddChildWindow(image)
    local count = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Count")
    count:SetArea({0, 222}, {0, 0}, {0, 40}, {1, 0})
    count:SetTextHorzAlign(0)
    count:SetTextVertAlign(1)
    count:SetTextColor({1, 228/255, 73/255, 1})
    cell:AddChildWindow(count)
    local join = GUIWindowManager.instance:CreateGUIWindow1("Button", "Join")
    join:SetArea({0, -10}, {0, 0}, {0, 84}, {0, 34})
    join:SetVerticalAlignment(1)
    join:SetHorizontalAlignment(2)
    join:SetNormalImage("set:new_gui_treasurebox.json image:green_btn_bg.png")
    join:SetPushedImage("set:new_gui_treasurebox.json image:green_btn_bg.png")
    cell:AddChildWindow(join)
    local btnText = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "ButtonTitle")
    btnText:SetArea({0, 0}, {0, -1}, {1, 0}, {0, 30})
    btnText:SetVerticalAlignment(1)
    btnText:SetTextHorzAlign(1)
    btnText:SetTextColor({1, 1, 247/255, 1})
    btnText:SetTextBoader({0, 57/255, 5/255, 1})
    btnText:SetText(Lang:toText("team.join"))
    join:AddChildWindow(btnText)
    return cell
end

local function updateTeamListCell(self, cell, teamInfo)
    local leader = Game.GetAllPlayersInfo()[teamInfo.leaderId] or {}
    cell:child("Name"):SetText(leader.name)
    cell:child("Count"):SetText(teamInfo.playerCount)
    if World.cfg.teamMemberLimit then
        cell:child("Join"):SetVisible(teamInfo.playerCount < World.cfg.teamMemberLimit)
    end
    self:unsubscribe(cell:child("Join"))
    self:subscribe(cell:child("Join"), UIEvent.EventButtonClick, function()
        Game.RequestJoinTeam(Me, teamInfo.id)
    end)
end

local function fillTeamList(self)
    local teamList = game_list[gameKey] or {}
    local oldCount = #teamListCells
    local newCount = #teamList
    if oldCount > newCount then
        for i = (oldCount - 1), newCount, -1 do--倒序，否则c++数组越界
            self.teamsList:DeleteItem(i)
            teamListCells[i + 1] = nil
        end
    end
    for i, teamInfo in ipairs(teamList) do
        local cell = teamListCells[i]
        if not cell then
            cell = createTeamCell()
            teamListCells[i] = cell
            self.teamsList:AddItem(cell)
        end
        updateTeamListCell(self, cell, teamInfo)
    end
end

local function updateTeamInfoCell(self, cell, player, leaderId, playerInfo)
    cell:child("Name"):SetText(player.name)
    cell:child("Level"):SetText("Lv."..playerInfo.level)
    cell:child("ExitBtn"):SetVisible(isLeader() and player.objID ~= leaderId)
    self:unsubscribe(cell:child("ExitBtn"))
    self:subscribe(cell:child("ExitBtn"), UIEvent.EventButtonClick, function()
        Game.RequestQuitTeamMember(Me, player.objID)
    end)
end

local function fillTeamInfo(self, team, membersInfo)
    local members = {}
    local players = Game.GetAllPlayersInfo()
    for objID, _ in pairs(team.playerList) do
        if players[objID] then
            table.insert(members, players[objID])
        end
    end
    if #members > 1 then
        table.sort(members, function(a, b)
            return a.joinTeamTime < b.joinTeamTime
        end)
    end
    self.teamInfoList:ClearAllItem()
    for _, player in ipairs(members) do
        if team.leaderId == player.objID then
            self.teamInfoTitle:SetText(Lang:toText({"team.leader", player.name}))
        end
        local cell = createMemberCell(self, player, team.leaderId, membersInfo[player.objID])
        self.teamInfoList:AddItem(cell)
    end
    local teamFull = World.cfg.teamMemberLimit and #members >= World.cfg.teamMemberLimit or false
    if isLeader() and not teamFull then
        local cell = createTeamWaitCell(self)
        self.teamInfoList:AddItem(cell)
    end
end

local function loadMemberInfo(self, team)
    Me:loadTeamMemberInfo(team.id, {"level"}, function(membersInfo)
        fillTeamInfo(self, team, membersInfo)
    end)
end

local function updateUI(self, updateTeamId)
    local teamId = Me:getValue("teamId") or 0
    local myTeam = Game.GetTeam(teamId)
    teamGameKey = myTeam and myTeam.additionalInfo and myTeam.additionalInfo.gameKey
    local showTeamInfo = teamId ~= 0
    self.teamsContent:SetVisible(not showTeamInfo)
    self.teamInfoContent:SetVisible(showTeamInfo)
    self.leaveContent:SetVisible(isLeader())
    self.gameInfo:SetVisible(not isLeader())
    self.gameName:SetVisible(teamGameKey and true or false)
    if teamGameKey then
        local fullName, chapterId, stage = table.unpack(Lib.splitString(teamGameKey, ","))
        local cfg = Stage.GetStageCfg(fullName, chapterId, stage)
        self.gameName:SetText(Lang:toText(cfg.name))
    end
    if teamId == 0 then
        fillTeamList(self)
        return
    end
    if updateTeamId ~= teamId and updateTeamId ~= 0 then
        return
    end
    loadMemberInfo(self, myTeam)
    local text = isLeader() and "team.fight" or "team.leave"
    self.fightTitle:SetText(Lang:toText(text))
end

local function sortOutData(self, updateTeamId)
    local teamsInfo = Game.GetAllTeamsInfo()
    local gameList = {}
    for teamID, teamInfo in pairs(teamsInfo) do
        local additionalInfo = teamInfo.additionalInfo or {}
        local gameKey = additionalInfo.gameKey
		local canJoin = additionalInfo.canJoin
        if gameKey and teamInfo.playerCount > 0 and canJoin ~= false then
            local teamList = gameList[gameKey] or {}
            table.insert(teamList, teamInfo)
            gameList[gameKey] = teamList
        end
    end
    local gameListSorted = {}
    for gameKey, teamList in pairs(gameList) do
        if #teamList > 1 then
            table.sort(teamList, function(a, b)
                return a.createTime < b.createTime
            end)
        end
        gameListSorted[gameKey] = teamList
    end
    game_list = gameListSorted
    updateUI(self, updateTeamId)
end


function M:init()
    WinBase.init(self, "TeamList.json", true)
    self.teamsContent = self:child("TeamList-Teams")
    self.teamInfoContent = self:child("TeamList-TeamInfo")
    self.teamsTitle = self:child("TeamList-TeamsTitle-Text")
    self.teamsTitle:SetText(Lang:toText("team.list"))
    self.teamInfoTitle = self:child("TeamList-TeamInfoTitle-Text")
    self.teamsList = self:child("TeamList-TeamsList")
    self.teamsList:SetInterval(7)
    self.teamInfoList = self:child("TeamList-TeamInfoList")
    self.teamInfoList:SetInterval(7)
    self.createTitle = self:child("TeamList-CreateTitle")
    self.createTitle:SetText(Lang:toText("team.create"))
    self.fightTitle = self:child("TeamList-FightTitle")
    self.createBtn = self:child("TeamList-CreateBtn")
    self.fightBtn = self:child("TeamList-FightBtn")
    self.leaveContent = self:child("TeamList-Leave")
    self.leaveBtn = self:child("TeamList-LeaveBtn")
    self.leaveTitle = self:child("TeamList-LeaveTitle")
    self.leaveTitle:SetText(Lang:toText("team.leave"))
    self.gameInfo = self:child("TeamList-GameInfo")
    self.gameName = self:child("TeamList-GameInfo-Text")

    self:subscribe(self.fightBtn, UIEvent.EventButtonClick, function()
        if isLeader() then
            local fullName, chapterId, stage = table.unpack(Lib.splitString(gameKey, ","))
            Stage.RequestStartStage(Me, fullName, chapterId, stage)
        else
            Game.RequestLeaveTeam(Me)
        end
    end)

    self:subscribe(self.leaveBtn, UIEvent.EventButtonClick, function()
        Game.RequestLeaveTeam(Me)
    end)

    self:subscribe(self.createBtn, UIEvent.EventButtonClick, function()
        Game.RequestCreateTeam(Me, {gameKey = gameKey})
    end)

    Lib.subscribeEvent(Event.EVENT_REFRESH_TEAMS_UI, function(packet)
        sortOutData(self, packet.teamID)
    end)
end

function M:setData(packet)
    gameKey = packet.data.gameKey
    local teamId = Me:getValue("teamId")
    sortOutData(self, teamId)

    local additionalInfo = Game.GetTeamAdditionalInfo(teamId) or {}
    local t_gameKey = additionalInfo.gameKey
    if isLeader() and (not t_gameKey or t_gameKey ~= gameKey)then
        Game.RequestUpdateTeamAdditionalInfo(Me, {gameKey = gameKey})
    end
end

return M
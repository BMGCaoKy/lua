local stopTimerList = {}

function M:init()
	WinBase.init(self, "Team-info.json", true)
	self.teamList = self:child("Team-info-team-list")
	self.teamTittle = self:child("Team-info-team-num")
end

function M:showTeamInfo(team)
	self.teamTittle:SetText(Lang:toText(team.teamTittleKey).." "..team.playerCount.."/"..team.maxNum)
	local teamList = team.entityListId
	for i,stop in ipairs(stopTimerList)do
		if stop then
			stop()
		end
	end
    stopTimerList = {}
	self.teamList:ClearAllItem()
	for i,v in ipairs(teamList)do
		if v~=Me.objID then
			local teamInfoLayout = GUIWindowManager.instance:CreateWindowFromTemplate("Teaminfo_Layout" ..i, "Teaminfo_Layout.json")
			local teamPlayerInfo = GUIWindowManager.instance:CreateWindowFromTemplate("Team-playerinfo" ..i, "Team-playerinfo.json")
			teamInfoLayout:GetChildByIndex(0):AddItem(teamPlayerInfo, true)
			self:subscribe(teamInfoLayout:GetChildByIndex(1), UIEvent.EventButtonClick, function()
				--踢出队伍
				Game.RequestQuitTeamMember(Me, v)
			end)
			teamInfoLayout:GetChildByIndex(1):SetVisible(Me.objID==team.leaderId)
			self.teamList:AddItem(teamInfoLayout, true)
			self:updataHp(v, teamPlayerInfo:GetChildByIndex(2):GetChildByIndex(0),teamPlayerInfo:GetChildByIndex(0),teamPlayerInfo:GetChildByIndex(1))
		end
	end

	self:subscribe(self:child("Team-info-leave-team"), UIEvent.EventButtonClick, function()
		--自己退出
		Game.RequestLeaveTeam(Me)
	end)

	Lib.subscribeEvent(Event.EVENT_REFRESH_TEAMS_UI, function()
		local team_id = Me:getValue("teamId")
		local playersInfo = Game.GetAllPlayersInfo()
		for i,v in pairs(playersInfo)do
			if team_id == v.teamID and team_id == 0 then
				for i,stop in ipairs(stopTimerList)do
					if stop then
						stop()
					end
				end
				stopTimerList = {}
				UI:closeWnd(self)
			end
		end
    end)
end

function M:updataHp(objId, hpPross, name, level)
	local function doUpdate(maxHp, curHp, entityName, entityLevel)
		hpPross:SetProgress(curHp / maxHp)
		name:SetText(entityName)
		level:SetText(entityLevel)
	end
	local tickCount = 0
	local function tick()
		tickCount = 2 + tickCount
		local entity = World.CurWorld:getEntity(objId)
		if entity then
			doUpdate(entity:prop("maxHp"), entity.curHp, entity.name, entity:getValue("level"))
		elseif tickCount % 20 == 0 then 
		    local packet = {
		        pid = "ReqTeammateInfo",
		        objId = objId
		    }
		    Me:sendPacket(packet, function (resp)
				doUpdate(resp.maxHp, resp.curHp, resp.name, resp.level)
		    end)
		end
	    return true
	end
	stopTimerList[#stopTimerList + 1] = World.Timer(2, tick)
end

return M

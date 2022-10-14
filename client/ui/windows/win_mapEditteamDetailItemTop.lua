local global_setting = require "editor.setting.global_setting"
local entity_obj = require "editor.entity_obj"

local enumColor = global_setting:getTeamColorList()
for k, v in pairs(enumColor) do
    enumColor[k] = string.upper(v)
end

local colorWnd = {}
local teams
local teamId
local teamInfo

function M:initUIName()
    self.numLayout = self:child("teamDetailItem-NumLayout")
end

function M:findColorIndex(color)
    for index, value in pairs(enumColor) do
        if value == color then
            return index
        end
    end
end

function M:getTeamTotalPlayerNum()
    local data = self:getData()
    local totalPlayerNumber = 0
    for index, teamData in pairs(data) do
        totalPlayerNumber = totalPlayerNumber + data[index].memberLimit
    end
    return totalPlayerNumber
end

function M:getOtherTeamTotalPlayerNum()
    local data = self:getData()
    local totalPlayerNumber = 0
    for index, teamData in pairs(data) do
        if index ~= self.teamIndex then
            totalPlayerNumber = totalPlayerNumber + data[index].memberLimit
        end
    end
    return totalPlayerNumber
end

function M:checkMinPlayerNum(value)
    if not value then
        return
    end

    local data = self:getData()
    local totalPlayerNumber = self:getTeamTotalPlayerNum()
    local otherTeamTotalPlayerNumber = self:getOtherTeamTotalPlayerNum()
    local currentTeamPlayerNumber = data[self.teamIndex].memberLimit
    -- local diff = totalPlayerNumber - currentTeamPlayerNumber
    local gameSettingWnd = UI:getWnd("mapEditGameSetting")
    local minPlayerNum
    if gameSettingWnd and gameSettingWnd:getMinPlayers() then
        minPlayerNum = gameSettingWnd:getMinPlayers()
    else
        minPlayerNum = global_setting:getMinPlayers()
    end
    local midMinPlayerNum = math.ceil(minPlayerNum / 2)

    if (value + otherTeamTotalPlayerNumber) < minPlayerNum and totalPlayerNumber < minPlayerNum and 
    currentTeamPlayerNumber < midMinPlayerNum then
        local diff = minPlayerNum - totalPlayerNumber
        currentTeamPlayerNumber = currentTeamPlayerNumber + diff
    else
        currentTeamPlayerNumber = value
    end
    self.numSliderWnd:invoke("setUIValue", currentTeamPlayerNumber)
    return currentTeamPlayerNumber
end

function M:init()
    WinBase.init(self, "teamDetailItemTop_edit.json")
    self:initUIName()
    self:child("teamDetailItem-Color-Text"):SetText(Lang:toText("win.map.global.setting.team.setting.color"))
	self.colorCell = UIMgr:new_widget("shopSell", "color")
    self.numSliderWnd = UILib.createSlider({value = 2, index = 6, listenType = "onFinishTextChange"}, function(value)
        if self.teamIndex then
            local data = self:getData()
            data[self.teamIndex].memberLimit = self:checkMinPlayerNum(value)
            self:saveData(data)
            global_setting:onGamePlayerNumberChanged("teams")
        end
    end)
    self.numSliderWnd:SetHeight({0, 100})
    self.numLayout:AddChildWindow(self.numSliderWnd)
    self:child("teamDetailItem-Color-Frame"):AddChildWindow(self.colorCell)
end

function M:saveData(data)
    global_setting:saveEditTeamMsg(data)
    global_setting:saveEditTeamMaxPlayerNum(self:getTeamTotalPlayerNum())
    self:updateUI()
end

function M:getData()
    return global_setting:getEditTeamMsg() or {}
end

function M:updateUI()
end

function M:onOpen(index)
    self.teamIndex = index
    local data = self:getData()
    local colorIndex = self:findColorIndex(data[self.teamIndex].color)
    self.colorCell:invoke("fillData", {
		index = colorIndex,
        backFunc = function(name, index)
            local teamDatas = self:getData()
            local ocolor = teamDatas[self.teamIndex].color
            local colorName = enumColor[index]
            for teamId, teamData in pairs(teamDatas) do
                if self.teamIndex ~= teamId and teamData.color == colorName then
                    data[teamId].color = ocolor
                end
            end
            data[self.teamIndex].color = colorName 
            self:saveData(data)
            Lib.emitEvent(Event.EVENT_CHANGE_TEAM_COLOR, colorName, self.teamIndex)
            entity_obj:delPointEntity()
            entity_obj:buildPointEntity()
		end
    })
    self:checkMinPlayerNum(data[self.teamIndex].memberLimit)
    self:updateUI()
end


function M:onClose()

end

function M:onReload()

end

return M
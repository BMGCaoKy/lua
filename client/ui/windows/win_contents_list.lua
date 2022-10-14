local allreward = 0
local rewardBySecond = 0
local isClose = false
local timeClose = true
local stop

function M:init()
    WinBase.init(self,"Contents_List.json")
    self.contentsTittle = self:child("Contents_List-contents_tittle")
    self.contents = self:child("Contents_List-contents")
    self.allreward = self:child("Contents_List-allReward")
    self.allrewardIcon = self:child("Contents_List-allRewardIcon")
    self.closeListWnd = self:child("Contents_List-close_list_wnd")
    self.closeListWnd:SetNormalImage("set:add_sub.json image:sub")
    self:subscribe(self:child("Contents_List-close_list_wnd"), UIEvent.EventButtonClick, function()
        self:closeList()
    end)
end

function M:setContents(tittle,icon,contentsList)
    if next(contentsList) == nil then
        UI:closeWnd(self)
        timeClose = false
        allreward = 0
        return
    end
    self.contents:ClearAllItem()
    self.contentsTittle:SetText(Lang:toText(tittle))
    rewardBySecond = 0
    timeClose = true
    self.allrewardIcon:SetImage(icon)
    for i, v in pairs (contentsList) do
        local contentslist = GUIWindowManager.instance:CreateWindowFromTemplate("contents" .. tostring(i), "Contents_template.json")
        local contentsName = contentslist:GetChildByIndex(0)
        local contentsImage = contentslist:GetChildByIndex(1)
        local contentsValue = contentslist:GetChildByIndex(2)
        contentsName:SetText(Lang:toText(i))
        contentsImage:SetImage(icon)
        contentsValue:SetText(Lang:toText(v))
        rewardBySecond = rewardBySecond + tonumber(string.match(v,"%d+"))
        self.contents:AddItem(contentslist, true)
    end
    if stop then
        stop()
    end
    self:tick(tittle, icon, contentsList)
end

function M:tick(tittle, icon, contentsList)
    local function tick()
        allreward = rewardBySecond + allreward
        self.allreward:SetText("+"..tostring(allreward))
		self.reloadArg = table.pack(allreward, rewardBySecond, isClose, timeClose, stop, tittle, icon, contentsList)
        return timeClose
    end
    stop = World.Timer(20, tick)
end
function M:closeList()
    if not isClose then
        isClose = true
        self.closeListWnd:SetNormalImage("set:add_sub.json image:add")
        self.contents:SetVisible(false)
    else
        isClose = false
        self.closeListWnd:SetNormalImage("set:add_sub.json image:sub")
        self.contents:SetVisible(true)
    end
end

function M:onReload(reloadArg)
	local _allreward, _rewardBySecond, _isClose, _timeClose, _stop, tittle, icon, contentsList= table.unpack(reloadArg or {}, 1, reloadArg and reloadArg.n)
	allreward = _allreward
	rewardBySecond = _rewardBySecond
	isClose = _isClose
	timeClose = _timeClose
	self:setContents(tittle, icon, contentsList)
	if _stop then
		_stop()
		_stop = nil
	end
end

return M

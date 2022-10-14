local waitingList	 = L("waitingList", {})
local progressTimer  = L("progressTimer")

function M:init()
	WinBase.init(self, "WaitDealList.json", true)
	self.bar = self:child("WaitDealList-bar")
	self.level = self:child("WaitDealList-level")
	self.desc = self:child("WaitDealList-desc")
	self.acceptBtn = self:child("WaitDealList-accept")
	self.rejectBtn = self:child("WaitDealList-reject")
    self.acceptBtn:SetText(Lang:toText("agree.join.team"))
    self.rejectBtn:SetText(Lang:toText("unagree.join.team"))
    self.count = self:child("WaitDealList-count")

    self:subscribe(self.rejectBtn, UIEvent.EventButtonClick, function(statu)
        self:doCallBack("no")
    end)

    self:subscribe(self.acceptBtn, UIEvent.EventButtonClick, function(statu)
        self:doCallBack("yes")
    end)
end

function M:onOpen()
	M:refresh()
end

function M:onClose()
	waitingList = {}
end

local function hasSame(data)
    for k,v in pairs(waitingList) do
        if v.name == data.name and v.desc == data.desc then 
            return true
        end
    end
    return false
end

function M:addWaitingList(data)
    if hasSame(data) then 
        Me:doRemoteCallback("waitDeal", "cancel", data.regId)
        return
    end
	waitingList[#waitingList + 1] = data
	if not waitingList[2] then 
		self:refresh()
    else
        self.count:SetText(#waitingList)
	end
end

function M:removeWaitingByType(rType)
	for i = #waitingList, 1, -1 do 
		if waitingList[i].type == rType then 
			local rmItem = table.remove(waitingList, i)
            Me:doRemoteCallback("waitDeal", "cancel", rmItem.regId)
		end
	end
end

function M:refresh()
	local data = waitingList[1]
	if data then 
		self.level:SetText("Lv."..data.level.." "..data.name)
		self.desc:SetText(Lang:toText(data.desc))
		self:updateProgressBar(data.offtime)
        self.count:SetText(#waitingList)
	end
end

function M:updateProgressBar(time)
    local mask = 1
    self.bar:SetProgress(mask)
    local upMask = 1 / (time / 10)
    local function tick()
        mask = mask - upMask
        if mask <= 0 then
            self.bar:SetProgress(0)
       		self:doCallBack("cancel")
            return false
        end
        self.bar:SetProgress(mask)
        return true
    end
    progressTimer = World.Timer(10, tick)
end

function M:doCallBack(key)
    if waitingList[1] then
		Me:doRemoteCallback("waitDeal", key, waitingList[1].regId)
		if key == "yes" then 
			self:removeWaitingByType(waitingList[1].type)
		else
			table.remove(waitingList, 1)
		end
        if progressTimer then 
            progressTimer()
            progressTimer = nil
        end
	  	World.Timer(1, self:refresh())
    end
    if not waitingList[1] then 
    	UI:closeWnd(self)
    end
end

return M

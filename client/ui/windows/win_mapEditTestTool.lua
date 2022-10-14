local gameList = {}
local isShowGameList = false

local function unifyProc(self, btn, proc)
    self:subscribe(btn, UIEvent.EventButtonClick, function()
        self:unsubscribe(btn)
        World.Timer(1, function()
            if not btn then
                return
            end
            unifyProc(self, btn, proc)
        end)
        if proc then
            proc()
        end
    end)
end

function M:init()
    WinBase.init(self, "toolTest_edit.json")

    self.test = self:child("ToolBar-Test")
    self.nextGame = self:child("ToolBar-NextGame")
	self.level = self:child("ToolBar-Level")
	self.gameName = self:child("ToolBar-GameName")
	self.gameName:SetText("Game name:" .. World.GameName)
	self.gameListWin = self:child("ToolBar-GameList") 
	self.gameListWin:SetInterval(10)
	self:initGameList()

	unifyProc(self, self:child("ToolBar-GameListBtn"), function()
		isShowGameList = not isShowGameList
		self.gameListWin:SetVisible(isShowGameList)
    end)

    unifyProc(self, self.test, function()
        Lib.emitEvent(Event.EVENT_EDIT_MAP_MAKING)
        World.Timer(5, function()
				local gameRootPath = CGame.Instance():getGameRootDir()
                CGame.instance:restartGame(gameRootPath, World.GameName, 1, false)
                return false
        end)
    end)

    self:subscribe(self.level, UIEvent.EventButtonClick, function()
        Lib.emitEvent(Event.EVENT_SHOW_STAGE_EDIT_LIST, true)
    end)

    unifyProc(self, self.nextGame, function()
		local gamePath = CGame.Instance():getGameRootDir()
		Lib.emitEvent(Event.EVENT_EDIT_MAP_MAKING)
		World.Timer(5, function()
			local gameRootPath = CGame.Instance():getGameRootDir()
			CGame.instance:restartGame(gameRootPath, self:findNextGameName(World.GameName), 1, true)
			return false
		end)
	end)
end

function M:initGameList()
	local gamePath = CGame.Instance():getGameRootDir()
	for fileName in lfs.dir(gamePath) do
		if fileName ~= "." and fileName ~= ".." then
			local fileattr = lfs.attributes(gamePath .. "/" .. fileName, "mode")
			if fileattr == "directory" then
				self:initList(gamePath, fileName)
				table.insert(gameList, fileName)
			end
		end
	end
end

function M:initList(gamePath, gName)
	local item = GUIWindowManager.instance:CreateGUIWindow1("Button", " ")
	item:SetText(gName)
	item:SetTextColor({1, 1, 1, 1})
	item:SetBackgroundColor({0.50916, 0, 1, 1})
	item:SetArea({0,0},{0,0},{1,0},{0,40})
	unifyProc(self, item, function()
		if gName == World.GameName then
			return
		end
		Lib.emitEvent(Event.EVENT_EDIT_MAP_MAKING)
		World.Timer(5, function()
			CGame.instance:restartGame(gamePath, gName, 1, true)
			return false
		end)
	end)
	self.gameListWin:AddItem(item)
end

function M:findNextGameName(gName)
	for i, name in ipairs(gameList) do
		if name == gName then
			return gameList[i + 1] or gameList[1]
		end
	end
end

return M
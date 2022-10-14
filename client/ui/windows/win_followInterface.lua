local function setPerspectiveDetails(self)
    --local flyBuff = "myplugin/friend_follow_free_mode_fly_buff" ---临时解决自由模式下的飞行，在各个游戏里加入
    if Me:getMode() == Me:getObserverMode() then
        self.perspectiveDesc.free:SetVisible(false)
        local targetId = Me:getTargetId()
        local target = World.CurWorld:getEntity(targetId)
        self.perspectiveDesc.follow.descText:SetText(Lang:toText("gui.lang.follow.perspective"))
        self.perspectiveDesc.follow.nameText:SetText(target and target.name)
        self.perspectiveDesc.follow.layout:SetVisible(true)
        self.perspectiveDesc.btnImg:SetImage("set:followInterface.json image:Perspective2")
        --Me:removeClientTypeBuff("fullName", flyBuff)
        UI:closeWnd("actionControl")
    else
        self.perspectiveDesc.follow.layout:SetVisible(false)
        self.perspectiveDesc.free:SetText(Lang:toText("gui.lang.free.perspective"))
        self.perspectiveDesc.free:SetVisible(true)
        self.perspectiveDesc.btnImg:SetImage("set:followInterface.json image:Perspective1")
        UI:openWnd("actionControl")

        --Me:addClientBuff(flyBuff)
    end
end
function M:init()
    WinBase.init(self, "FollowInterface.json", true)
    self:child("joinText"):SetText(Lang:toText("gui.lang.joinGame"))
    self.quitBtn = self:child("quitBtn")
    self.joinBtn = self:child("joinBtn")
    self.tipsImg = self:child("tipsImg")
    self.tipsText = self:child("tipsText")
    self.perspectiveBtn = self:child("perspectiveBtn")
    self.perspectiveDesc = {
        layout = self:child("perspectiveDesc"),
        btnImg = self:child("btnShowImg"),
        follow = {
            layout = self:child("follow"),
            descText = self:child("descText"),
            nameText = self:child("nameText")
        },
        free = self:child("freeText")
    }
    setPerspectiveDetails(self)
    self.tipsTimer = nil
    self:checkOrSetJoinGame()
    self:initEvent()
end

function M:onOpen()

end

function M:onClose()

end

function M:textShow(text, openTimer)
    self.tipsImg:SetVisible(true)
    self.tipsText:SetText(Lang:toText(text))
    if openTimer then
        if self.tipsTimer then
            self.tipsTimer(); self.tipsTimer = nil
        end
        self.tipsTimer = World.Timer(20*2, function()
            self.tipsImg:SetVisible(false)
        end)
    end
end

local joinGameLimit = false
function M:checkOrSetJoinGame(join)
    if not Me:isWatch() then
        return
    end
    local setBtn = function(booleanVal)
        self.joinBtn:SetTouchable(booleanVal)
        self.joinBtn:SetEnabled(booleanVal)
    end
    Me:sendPacket({pid = "FollowEnterGame"}, function (info)
        local text = nil
        if info.watchMode == 2 then ---该模式下不允许加入游戏；只能观战
            text = "gui.lang.cannot.join.game.in.this.mode"
        elseif info.curNum >= info.maxNum then ---当前服务器已满，正在观战，请耐心等待服务器空闲
            text = "gui.lang.server.full.cannot.join.game"
        end
        if text then
            setBtn(false)
            if self.tipsTimer then
                self.tipsTimer(); self.tipsTimer = nil
            end
            self.tipsImg:SetVisible(true)
            self.tipsText:SetText(Lang:toText(text))
        elseif not joinGameLimit and join then
            joinGameLimit = true
            CGame.instance:getShellInterface():followEnterGame(info.userId, World.GameName)
            World.Timer(100, function()
                joinGameLimit = false
            end)
        else
            self.tipsImg:SetVisible(false)
            setBtn(true)
        end
    end)
end

function M:initEvent()
    self:subscribe(self.quitBtn, UIEvent.EventButtonClick, function()
        --CGame.instance:exitGame()
        Me:followInterfaceDataReport({"follow_quit_watch"})
        Lib.emitEvent(Event.EVENT_MENU_EXIT)
    end)

    self:subscribe(self.joinBtn, UIEvent.EventButtonClick, function()
        if Me:getTargetId() ~= 0 then
            Me:followInterfaceDataReport({"follow_game_enter"}) --点击加入游戏时的数据上报
            self:checkOrSetJoinGame(true)
        end
    end)
    self:subscribe(self.perspectiveBtn, UIEvent.EventButtonClick, function()
        Me:followInterfaceDataReport({"follow_game_switch"})
        if Me:getMode() == Me:getObserverMode() then
            Me:changeEntityMode(Me:getFreedomMode())
        else
            Me:changeEntityMode(Me:getObserverMode())
        end
    end)
    Lib.subscribeEvent(Event.EVENT_UPDATE_UI_DATA, function(UIName, data)
        if UIName == "followInterface" then
            setPerspectiveDetails(self)
        elseif UIName == "resetGameResult2FollowInterface" then
            self:textShow(data, true)
        end
    end)
    Lib.subscribeEvent(Event.EVENT_PLAYER_LOGIN, function(_)
        self:checkOrSetJoinGame()
    end)
    Lib.subscribeEvent(Event.EVENT_PLAYER_LOGOUT, function(_)
        self:checkOrSetJoinGame()
    end)
end

return M
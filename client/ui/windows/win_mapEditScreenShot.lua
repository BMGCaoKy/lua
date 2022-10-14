local editorUtil = require "editor.utils"
local globalSetting = require "editor.setting.global_setting"

function M:init()
    WinBase.init(self, "screenShot_edit.json")

    self.leftCheckBox = self:child("ScreenShotLayout-LeftCheckbox")
    self.rightCheckBox = self:child("ScreenShotLayout-RightCheckbox")

    self.releaseLayout = self:child("ScreenShotLayout-ReleaseLayout")
    self.noReleaseLayout = self:child("ScreenShotLayout-NoReleaseLayout")

    self.releaseLeftImg = self:child("ScreenShotLayout-LeftImg")
    self.releaseRightImg = self:child("ScreenShotLayout-RightImg")
    self.noReleaseImg = self:child("ScreenShotLayout-NoRelease-Img")

    self:initLang()
    self:initSubscribe()
end

function M:initLang()
    self:child("ScreenShotLayout-Content-Title"):SetText(Lang:toText("win.screenShot.backHome"))
    self:child("ScreenShotLayout-Content-Tip"):SetText(Lang:toText("win.screenShot.selectImg"))
    self:child("ScreenShotLayout-LeftText"):SetText(Lang:toText("win.screenShot.useCurrentImg"))
    self:child("ScreenShotLayout-RightText"):SetText(Lang:toText("win.screenShot.useNewImg"))
    self:child("ScreenShotLayout-NoRelease-Text"):SetText(Lang:toText("win.screenShot.autoScreenShot"))
    self:child("ScreenShotLayout-CancelBtn"):SetText(Lang:toText("global.cancel"))
    self:child("ScreenShotLayout-SureBtn"):SetText(Lang:toText("win.screenShot.saveAndExit"))
end

function M:setCheckBoxStatus(isSelectLeft)
    self.leftCheckBox:SetChecked(isSelectLeft)
    self.rightCheckBox:SetChecked(not isSelectLeft)
end

local function saveAndBackHome()
    handle_mp_editor_command("save_MpMap", {path = ""})
    Lib.emitEvent(Event.EVENT_EDIT_MAP_MAKING)
    local count = 0
    World.Timer(1, function()
         if count > 5 then
            CGame.instance:getShellInterface():killAppProcess()
            return false
         end
         count = count + 1
         return true
    end)
end

function M:initSubscribe()

    self:subscribe(self:child("ScreenShotLayout-LeftBottomLayout"), UIEvent.EventWindowTouchUp, function()
        self:setCheckBoxStatus(true)
    end)

    self:subscribe(self:child("ScreenShotLayout-RightBottomLayout"), UIEvent.EventWindowTouchUp, function()
        self:setCheckBoxStatus(false)
    end)

    self:subscribe(self:child("ScreenShotLayout-CancelBtn"), UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)

    self:subscribe(self:child("ScreenShotLayout-SureBtn"), UIEvent.EventButtonClick, function()
        if self.isRelease and self.leftCheckBox:GetChecked() then
            editorUtil:removeScreenShot()
        end

        if not self.isRelease or self.rightCheckBox:GetChecked() then
            globalSetting:saveIsUseNewScreenShot(true, true)
        end
        saveAndBackHome()
    end)
end

function M:onOpen(screenShotImgPath)
    local screenShotInfo = editorUtil:getCertainScreenShotInfo()
    self.isRelease = screenShotInfo.coverLocalPath or screenShotInfo.coverUrl
    self:child("ScreenShotLayout-Content-Tip"):SetVisible(self.isRelease)
    if self.isRelease then
        self.releaseLayout:SetVisible(true)
        self.noReleaseLayout:SetVisible(false)
        self.leftCheckBox:SetChecked(true)
        if screenShotInfo.coverLocalPath then
            self.releaseLeftImg:SetImage(screenShotInfo.coverLocalPath)
        elseif screenShotInfo.coverUrl then
            self.releaseLeftImg:SetImageUrl(screenShotInfo.coverUrl)
        end
        self.releaseRightImg:SetImage(screenShotImgPath.rectangle)
    else
        self.releaseLayout:SetVisible(false)
        self.noReleaseLayout:SetVisible(true)
        self.noReleaseImg:SetImage(screenShotImgPath.rectangle)
    end
end
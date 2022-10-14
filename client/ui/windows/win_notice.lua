
local setting = require "common.setting"

function M:init()
    WinBase.init(self, "Notice.json", true)
    self.mask = self:child("Notice-Mask")
    self.bigBg = self:child("Notice-Content1")
    self.smallBg = self:child("Notice-Small-Bg1")
    self.titleBg = self:child("Notice-Title-Bg1")
    self.title = self:child("Notice-Title-Text1")
    self.closeBtn = self:child("Notice-Close1")
    self.detailBg = self:child("Notice-DetailBg1")
    self.detail = self:child("Notice-Detail-Text1")
    self.sureBtn = self:child("Notice-Sure-Btn1")
    self.sureTitle = self:child("Notice-Sure-Text1")
    self.yesBtn = self:child("Notice-Yes-Btn1")
    self.yesTitle = self:child("Notice-Yes-Text1")
    self.noBtn = self:child("Notice-No-Btn1")
    self.noTitle = self:child("Notice-No-Text1")
    self.icon = self:child("Notice-Icon1")
    self.count = self:child("Notice-Count1")

    self:subscribe(self.noBtn, UIEvent.EventButtonClick, function(statu)
        self:doCallBack("no")
    end)

    self:subscribe(self.yesBtn, UIEvent.EventButtonClick, function(statu)
        self:doCallBack("yes")
    end)

    self:subscribe(self.sureBtn, UIEvent.EventButtonClick, function(statu)
        self:doCallBack("sure")
    end)

    self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function(statu)
        UI:closeWnd(self)
    end)
end

function M:setArg(data)
    self.regId = data.regId
    self.callBack = data.callBack
    local btnType = data.buttonType or 1
    self.mask:SetVisible(data.showMask or false)
    self.closeBtn:SetVisible(data.showCloseBtn or false)
    self.sureBtn:SetVisible(btnType == 1)
    self.yesBtn:SetVisible(btnType == 2)
    self.noBtn:SetVisible(btnType == 2)
    self.title:SetText(Lang:toText(data.titleKey or ""))
    self.yesTitle:SetText(Lang:toText(data.yesKey or "Yes"))
    self.noTitle:SetText(Lang:toText(data.noKey or "No"))
    self.sureTitle:SetText(Lang:toText(data.sureKey or "Sure"))
    self.detail:SetText(Lang:toText({data.content, table.unpack(data.textArgs)}))
    self.icon:SetVisible(data.itemIcon and true or false)
    self.count:SetVisible(data.itemCount and true or false)
    if data.itemIcon then
        self.icon:SetImage(data.itemIcon)
    end
    if data.itemCount then
        self.count:SetText(data.itemCount)
    end

    local uiCfg = data.uiCfg
    if not uiCfg then
        return
    end
    local base_plugin = Me:cfg().plugin
    local cfg = setting:fetch("ui_config", not string.find( uiCfg, base_plugin .. "/") and (base_plugin .. "/" .. uiCfg) or uiCfg)
    local closeBtn = cfg.closeBtn or {}
    self.closeBtn:SetVisible(cfg.closeBtn and true or false)
    if closeBtn.image then
        self.closeBtn:SetNormalImage(closeBtn.image)
        self.closeBtn:SetPushedImage(closeBtn.image)
    end
    if closeBtn.area then
        self.closeBtn:SetArea(table.unpack(closeBtn.area))
    end
    local bgImage = cfg.bgImage or {}
    self.bigBg:SetImage(bgImage.name or "")
    self.bigBg:SetProperty("StretchType", bgImage.stretchType or "None")
    self.bigBg:SetProperty("StretchOffset", bgImage.stretchOffset or "0 0 0 0")
    if bgImage.area then
        self.bigBg:SetArea(table.unpack(bgImage.area))
    end
    local title = cfg.title or {}
    local titleBg = title.image
    if titleBg then
        self.titleBg:SetImage(titleBg.name or "")
        self.titleBg:SetProperty("StretchType", titleBg.stretchType or "None")
        self.titleBg:SetProperty("StretchOffset", titleBg.stretchOffset or "0 0 0 0")
    end
    local tb = title.border
    if tb then
        self.title:SetTextBoader({tb[1]/255, tb[2]/255, tb[3]/255, tb[4]/255})
    end
    if title.fontSize then
        self.title:SetFontSize(title.fontSize)
    end
    if title.area then
        self.titleBg:SetArea(table.unpack(title.area))
    end
    local smallBg = cfg.smallBgImage
    if smallBg then
        self.smallBg:SetImage(smallBg.name or "")
        self.smallBg:SetProperty("StretchType", smallBg.stretchType or "None")
        self.smallBg:SetProperty("StretchOffset", smallBg.stretchOffset or "0 0 0 0")
        if smallBg.area then
            self.smallBg:SetArea(table.unpack(smallBg.area))
        end
    end
    local content = cfg.content or {}
    if content.area then
        self.detailBg:SetArea(table.unpack(content.area))
    end
    local contentBg = content.image
    if contentBg then
        self.detailBg:SetImage(contentBg.name or "")
        self.detailBg:SetProperty("StretchType", contentBg.stretchType or "None")
        self.detailBg:SetProperty("StretchOffset", contentBg.stretchOffset or "0 0 0 0")
    end
    if content.fontSize then
        self.detail:SetFontSize(content.fontSize)
    end
    local cb = content.border
    if cb then
        self.detail:SetTextBoader({cb[1]/255, cb[2]/255, cb[3]/255, cb[4]/255})
    end
    local cc = content.color
    if cc then
        self.detail:SetTextColor({cc[1]/255, cc[2]/255, cc[3]/255, cc[4]/255})
    end

    local yesBtn = cfg.yesBtn
    if yesBtn then
        self.yesBtn:SetNormalImage(yesBtn.name)
        self.yesBtn:SetPushedImage(yesBtn.name)
        self.yesBtn:SetProperty("StretchType", yesBtn.stretchType or "None")
        self.yesBtn:SetProperty("StretchOffset", yesBtn.stretchOffset or "0 0 0 0")
        local bd = yesBtn.titleBorder
        if bd then
            self.yesTitle:SetTextBoader({bd[1]/255, bd[2]/255, bd[3]/255, bd[4]/255})
        end
        local tc = yesBtn.titleColor
        if tc then
            self.yesTitle:SetTextColor({tc[1]/255, tc[2]/255, tc[3]/255, tc[4]/255})
        end
    end
    local noBtn = cfg.noBtn
    if noBtn then
        self.noBtn:SetNormalImage(noBtn.name)
        self.noBtn:SetPushedImage(noBtn.name)
        self.noBtn:SetProperty("StretchType", noBtn.stretchType or "None")
        self.noBtn:SetProperty("StretchOffset", noBtn.stretchOffset or "0 0 0 0")
        local bd = noBtn.titleBorder
        if bd then
            self.noTitle:SetTextBoader({bd[1]/255, bd[2]/255, bd[3]/255, bd[4]/255})
        end
        local tc = noBtn.titleColor
        if tc then
            self.yesTitle:SetTextColor({tc[1]/255, tc[2]/255, tc[3]/255, tc[4]/255})
        end
    end
    local sureBtn = cfg.sureBtn
    if sureBtn then
        self.sureBtn:SetNormalImage(sureBtn.name)
        self.sureBtn:SetPushedImage(sureBtn.name)
        self.sureBtn:SetProperty("StretchType", sureBtn.stretchType or "None")
        self.sureBtn:SetProperty("StretchOffset", sureBtn.stretchOffset or "0 0 0 0")
        local bd = sureBtn.titleBorder
        if bd then
            self.sureTitle:SetTextBoader({bd[1]/255, bd[2]/255, bd[3]/255, bd[4]/255})
        end
        local tc = sureBtn.titleColor
        if tc then
            self.yesTitle:SetTextColor({tc[1]/255, tc[2]/255, tc[3]/255, tc[4]/255})
        end
    end
    local confirmBtn = cfg.confirmBtn or {}
    local btnSize = confirmBtn.size
    if btnSize then
        self.yesBtn:SetWidth(btnSize[1])
        self.noBtn:SetWidth(btnSize[1])
        self.sureBtn:SetWidth(btnSize[1])
        self.yesBtn:SetHeight(btnSize[2])
        self.noBtn:SetHeight(btnSize[2])
        self.sureBtn:SetHeight(btnSize[2])
    end
    local fz = confirmBtn.titleFontSize
    if fz then
        self.yesTitle:SetFontSize(fz)
        self.noTitle:SetFontSize(fz)
        self.sureTitle:SetFontSize(fz)
    end
    local titleOffsetY = confirmBtn.titleOffsetY
    if titleOffsetY then
        self.yesTitle:SetYPosition(titleOffsetY)
        self.noTitle:SetYPosition(titleOffsetY)
        self.sureTitle:SetYPosition(titleOffsetY)
    end
    local btnOffsetY = confirmBtn.buttonOffsetY
    if btnOffsetY then
        self.yesBtn:SetYPosition(btnOffsetY)
        self.noBtn:SetYPosition(btnOffsetY)
        self.sureBtn:SetYPosition(btnOffsetY)
    end
    local item = cfg.item or {}
    if item.iconArea then
        self.icon:SetArea(table.unpack(item.iconArea))
    end
    if item.textArea then
        self.count:SetArea(table.unpack(item.textArea))
    end
    if item.fontSize then
        self.count:SetFontSize(item.fontSize)
    end
    local ib = item.border
    if ib then
        self.count:SetTextBoader({ib[1]/255, ib[2]/255, ib[3]/255, ib[4]/255})
    end
end

function M:doCallBack(key)
    if self.callBack then
        self.callBack(key)
    elseif self.regId then
        Me:doCallBack("notice", key, self.regId)
    end
    UI:closeWnd(self)
end

function M:onReload(reloadArg)
	local data = table.unpack(reloadArg or {}, 1, reloadArg and reloadArg.n)
	self:setArg(data)
end

function M:onClose()
    self.regId = nil
    self.callBack = nil

    self.bigBg:SetImage("")
    self.smallBg:SetImage("")
    self.titleBg:SetImage("")
    self.title:SetText("")
    self.detailBg:SetImage("")
    self.detail:SetText("")
    self.sureTitle:SetText("")
    self.yesTitle:SetText("")
    self.noTitle:SetText("")
    self.icon:SetImage("")
    self.count:SetText("")
end

return M

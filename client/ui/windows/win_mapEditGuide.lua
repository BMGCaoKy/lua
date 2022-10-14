local cnImage = 
{
    "fixed_cn_1_main.png",
    "fixed_cn_4_move.png",
    "fixed_cn_5_monster.png",
    "fixed_cn_2_stage.png",
    "fixed_cn_3_building_tools.png",  
}

local enImage =
{
    "fixed_en_1_main.png",
    "fixed_en_4_move.png",
    "fixed_en_5_monster.png",
    "fixed_en_2_stage.png",
    "fixed_en_3_building_tools.png"
}


function M:init()
	WinBase.init(self, "guide_edit.json")
    self.guideBg = self:child("Guide-Bg")
    self:child("Guide-Btn-Text"):SetText(Lang:toText("win.map.edit.guide.text"))
    self:root():setBelongWhitelist(true)
    if World.Lang == "zh_CN" then
        self.image = cnImage
    else
        self.image = enImage
    end
    self:subscribe(self:child("Guide-Btn"), UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
        Me:setGuideStep("step" .. tostring(self.index))
    end)
end

function M:onClose()
end

function M:onOpen(index)
    self.index = index or 1
    self.guideBg:SetImage("image/" .. self.image[index])
    UI:closeWnd("mapEditGuideTip")
end

function M:onReload()
end

return M

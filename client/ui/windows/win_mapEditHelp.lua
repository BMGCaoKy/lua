function M:init()
    WinBase.init(self, "help_edit.json")
    self.close = self:child("Help-Close")
    self.left = self:child("Help-Left")
    self.imageLeft = self:child("Help-ImageLeft")
    self.right = self:child("Help-Right")
    self.imageRight = self:child("Help-ImageRight")
    self.image = self:child("Help-Image")

    self.index = 1

    if World.Lang == "zh_CN" then
        self.imageList = {"image/cn_1_main.png",
                          "image/cn_2_stage.png",
                          "image/cn_3_building_tools.png",
                          "image/cn_4_move.png",
                          "image/cn_5_monster.png"}
    else
        self.imageList = {"image/en_1_main.png",
                          "image/en_2_stage.png",
                          "image/en_3_building_tools.png",
                          "image/en_4_move.png",
                          "image/en_5_monster.png"}
    end

    self:subscribe(self.close, UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
    end)

    self:subscribe(self:child("Help-BG"), UIEvent.EventWindowClick, function()
        UI:closeWnd(self)
    end)

    self:subscribe(self.left, UIEvent.EventButtonClick, function()
        self:ClickLeft()
    end)

    
    self:subscribe(self.imageLeft, UIEvent.EventWindowClick, function()
        self:ClickLeft()
    end)

    self:subscribe(self.right, UIEvent.EventButtonClick, function()
        self:ClickRight()
    end)

     self:subscribe(self.imageRight, UIEvent.EventWindowClick, function()
       self:ClickRight()
    end)

end

function M:ClickLeft()
    if  self.index > 1 then
		self.index =  self.index - 1
        self:setImage(self.index)
    end
end

function M:ClickRight()
    if  self.index < #self.imageList then
        self.index =  self.index + 1
        self:setImage(self.index)
    end
end

function M:onOpen()
       self.index = 1
       self:setImage(self.index)
       self.right:SetVisible(true)
       self.imageRight:SetVisible(true)
end

function M:onReload(reloadArg)
    
end

function M:setImage(index)

    if index == #self.imageList then
        self.right:SetVisible(false)
        self.imageRight:SetVisible(false)
    elseif index == 1 then
        self.left:SetVisible(false)
        self.imageLeft:SetVisible(false)
    elseif index == 2 or index == #self.imageList - 1 then
        self.right:SetVisible(true)
        self.left:SetVisible(true)
        self.imageRight:SetVisible(true)
        self.imageLeft:SetVisible(true)
    end

    self.image:SetImage(self.imageList[index])
end

return M
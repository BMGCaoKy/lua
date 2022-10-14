local defaultTime = 20

function M:init()
    WinBase.init(self, "toaster_edit.json")
    self:root():SetLevel(1)
end

function M:setToast(text, time)
    local moveItem  = GUIWindowManager.instance:LoadWindowFromJSON("toast_edit.json")
    self._root:AddChildWindow(moveItem)
    moveItem:SetArea({0, 0}, {0, -100}, {0, 800}, {0, 50})
    moveItem:child("Edit_Toast-Tip-Text"):SetText(text)
    local width = moveItem:GetFont():GetTextExtent(text,1.0) + 50
    moveItem:SetWidth({0 , width })
    moveItem:SetVisible(true)
    Lib.uiTween(moveItem, {
        Y = {0, -200},
        Alpha = 0.5
    }, time or defaultTime, function()
        moveItem:SetVisible(false)
        self._root:RemoveChildWindow1(moveItem)
    end)
end
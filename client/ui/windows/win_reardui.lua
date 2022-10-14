local use = {}
local save = {}
function M:init()
    WinBase.init(self, "Rewardbase.json")
end

function M:setRewardUi(image, text)
    local move = nil
    if not self._root:IsVisible() then
        self:show()
    end
    if #save<=0 then
        move = GUIWindowManager.instance:CreateWindowFromTemplate("RewardUi", "RewardUi.json")
        table.insert(use, move)
    end
    if move == nil then
        move = save[1]
        table.remove(save, 1)
        table.insert(use, move)
    end
    local base = move:GetChildByIndex(0)
    local _setimage = base:GetChildByIndex(0)
    local _settext = base:GetChildByIndex(1)
    _setimage:SetImage(image)
    _settext:SetText(text)
    self._root:AddChildWindow(move)
    local time = 30
    local sub = 0
    local function tick()
       time = time - 1
            move:SetArea({ 0, 0 }, { 0, sub }, { 1, 0 }, { 0, 0 })
            move:SetVisible(true)
       if time <= 12 then
            --move:SetArea({ s = 0, t = 0 }, { s = 0, t = sub }, { s = 1, t = 0 }, { s = 0, t = 0 })
            sub = sub - 20
       end
       if time <= 0 then
            move:SetVisible(false)
            UI:closeWnd(self)
            table.remove(use, 1)
            table.insert(save, move)
            return false
       end
       return true
    end
    World.Timer(1, tick)
end

return M
local stageSetting = require "editor.stage_setting"
local data_state = require "editor.dataState"
local network_mgr = require "network_mgr"

local isGuide = true
local stageItemIndexImageSize = { {27 * 0.8, 50 * 0.8},
                                  {40 * 0.8, 50 * 0.8},
                                  {39 * 0.8, 50 * 0.8},
                                  {41 * 0.8, 50 * 0.8},
                                  {40 * 0.8, 50 * 0.8}
                                }

function M:init()
    WinBase.init(self, "stage_edit.json")
    isGuide = Clientsetting.isKeyGuide("isGuideStage")
    self.listShow = true
    self.stageListShow = self:child("Edit_Stage-StageList")
    self.stageListCopy = self:child("Edit_Stage-StageList-1")
    self.delTipWin = self:child("Edit_Stage-DeleteTip")
    self.addStageWin1 = self:child("Edit_Stage-AddStage-Bg")
    self.addStageReturnBtn1 = self:child("Edit_Stage-AddStage-ReturnBtn")
    self.addStageWin2 = self:child("Edit_Stage-AddStage-Bg-1")
    self.addStageReturnBtn2 = self:child("Edit_Stage-AddStage-ReturnBtn-1")
    self.addStageBtn = self:child("Edit_Stage-AddStage-Btn")
    self.addStageTemplateBtn = self:child("Edit_Stage-AddStage-TemplateBtn")
    self.addStageCopyBtnBtn = self:child("Edit_Stage-AddStage-CopyBtn")
    self:child("Edit_Stage-Title"):SetText(Lang:toText("win.stage.title"))
    self:child("Edit_Stage-Title_1"):SetText(Lang:toText("win.stage.title"))
    self:child("Edit_Stage-AddStage-Btn-text"):SetText(Lang:toText("win.stage.add.stage"))
    self:child("Edit_Stage-AddStage-TemplateBtn-Text"):SetText(Lang:toText("win.stage.add.stage.templatebtn.text"))
    self:child("Edit_Stage-AddStage-CopyBtn-Text"):SetText(Lang:toText("win.stage.add.stage.copybtn.text"))
    self:child("Edit_Stage-DeleteTip-Info"):SetText(Lang:toText("win.map.edit.stage.delete.tip"))
    self:child("Edit_Stage-DeleteTip-SureBtn"):SetText(Lang:toText("win.map.edit.entity.setting.fetch.delete"))
    self:child("Edit_Stage-DeleteTip-CancelBtn"):SetText(Lang:toText("character_panel_cancleBtn"))
    self:child("Edit_Stage-DeleteTip-Title"):SetText(Lang:toText("composition.replenish.title"))
    if World.Lang == "zh_CN" then
        self:child("Edit_Stage-DeleteTip-Title"):SetXPosition({0 , 0})
    end
    self.addStageWin2:SetVisible(false)
    self.addStageWin1:SetVisible(false)
    self.items = {}
    self:subscribe(self:child("Edit_Stage-DeleteTip-SureBtn"), UIEvent.EventButtonClick, function()
        CGame.instance:onEditorDataReport("click_stage_del_page_sure", "")
        self.delTipWin:SetVisible(false)
        local stageList = stageSetting:getStageList()
        self.stageListShow:DeleteItem(#stageList - 1)
        local tempIndex = self.targetDelIndex
        self:delStage(#stageList)
        self.stageListShow:ResetScroll()
    end)
    self:subscribe(self:child("Edit_Stage-DeleteTip-CancelBtn"), UIEvent.EventButtonClick, function()
        self:closeDeleteTip()
    end)
    self:subscribe(self:child("Edit_Stage-DeleteTip-Bg"), UIEvent.EventWindowClick, function()
        self:closeDeleteTip()
    end)
    self.delTipWin:SetVisible(false)
    self:subscribe(self.addStageBtn, UIEvent.EventButtonClick, function()
        CGame.instance:onEditorDataReport("click_stage_addnewstage", "")
        self.addStageWin1:SetVisible(true)
        self.listShow = false
        if isGuide then
            self.addStageTemplateBtn:SetName("addStageTemplateBtn")
        end
    end)
    self:subscribe(self:child("Edit_Stage-AddStage-ReturnBtn"), UIEvent.EventButtonClick, function()
        self.addStageWin1:SetVisible(false)
        self.listShow = true
        self:refreshStageList()
    end)
    self:subscribe(self.addStageReturnBtn2, UIEvent.EventButtonClick, function()
        self.addStageWin2:SetVisible(false)
        if isGuide then
            self.addStageReturnBtn1:SetName("AddStageReturnBtn1")
        end
    end)

    self:subscribe(self.addStageReturnBtn1, UIEvent.EventButtonClick, function()
        if isGuide then
            Lib.emitEvent(Event.EVENT_NOVICE_GUIDE, 4, true)
            isGuide = false
            Clientsetting.setlocalGuideInfo("isGuideStage", false)
            local retry = 1
            World.Timer(5, function() 
                local respone = network_mgr:set_client_cache("isGuideStage", "1")
                if respone.ok or retry > 5 then
					if respone.ok then
						Clientsetting.setGuideInfo("isGuideStage", false)
					end
                    return false
                end
                retry = retry + 1
                return true
            end)
        end
    end)
    self:subscribe(self.addStageTemplateBtn, UIEvent.EventButtonClick, function()
        CGame.instance:onEditorDataReport("click_stage_addnewstage_newmap", "")
        self:addStage()
        if isGuide then
            self.addStageCopyBtnBtn:SetName("AddStageCopyBtnBtn")
        end
    end)
    self:subscribe(self.addStageCopyBtnBtn, UIEvent.EventButtonClick, function()
        CGame.instance:onEditorDataReport("click_stage_addnewstage_copymap", "")
        self.addStageWin2:SetVisible(true)
        self:refreshStageList()
        if isGuide then
            if self.tempItem then
                 self.tempItem:child("Edit_Stage_Item-CopyBtn"):SetName("Stage_Item-CopyBtn")
            end
        end
    end)
    Lib.subscribeEvent(Event.EVENT_STAGE_LIST_CHANGED, function()
        --self:refreshStageList()
    end)
    self:subscribe(self:child("Edit_Stage-CloseBtn"), UIEvent.EventButtonClick, function()
        self:closeStage()
       
    end)
    self:subscribe(self:child("Edit_Stage-CloseMask"), UIEvent.EventWindowClick, function()
        self:closeStage()
    end)
end

function M:fetchItem(i , maxId)
    local stageItem = GUIWindowManager.instance:LoadWindowFromJSON("stageItem_edit.json")
    if maxId == 1 then
        --stageItem:child("Edit_Stage_Item-UpBtn"):SetVisible("false")
        stageItem:child("Edit_Stage_Item-DownBtn"):SetVisible("false")
    end
    if i==1 then
        stageItem:child("Edit_Stage_Item-UpBtn"):SetVisible("false")
        stageItem:child("Edit_Stage_Item-DownBtn"):SetArea({ 0, 0 }, {  0, 0 }, { 0 , 55 }, { 0 , 55 })
    end
    if i==maxId then
        stageItem:child("Edit_Stage_Item-DownBtn"):SetVisible("false")
        stageItem:child("Edit_Stage_Item-UpBtn"):SetArea({ 0, 0 }, { 0, 0 }, { 0 , 55 }, { 0 , 55 })
    end 
    stageItem:SetArea({ 0, 0 }, { 0, 0 }, { 0 , 468 }, { 0 , 194 })
    return stageItem
end

function M:refreshStageList()
    local stages = stageSetting:getStageList()
    self.icons = stageSetting:getStageIconList()
    local list = self.listShow and self.stageListShow or self.stageListCopy
    list:ClearAllItem()
    for i = 1, #stages do
        local stageItem = self:fetchItem(i, #stages)
        self:setStageItem(stageItem, i, stages[i], false, i)
        list:AddItem(stageItem, true)
        self.items[i] = stageItem
    end
end

function M:setStageItem(item, index, name, test, iconIndex)
    local stageOrderNum = item:child("Edit_Stage_Item-StageOrder-Number")
    stageOrderNum:SetImage("set:map_edit_setCheckpointNumber.json image:"..index)
    stageOrderNum:SetArea({0, 0}, {0.108108, 0}, {0, stageItemIndexImageSize[index][1]}, {0, stageItemIndexImageSize[index][2]})
    local nameEdit = item:child("Edit_Stage_Item-StageName-Edit")
    nameEdit:SetText(name)
    nameEdit:SetTextColor({0.094117, 0.674509, 0.474509, 1})
    --nameEdit:SetTextBoader({0.094117, 0.674509, 0.474509})
    --self.icons = stageSetting:getStageIconList()
    
    local width = nameEdit:GetFont():GetTextExtent(name,1.0) + 40
    local nameEdit1 = item:child("Edit_Stage_Item-StageName-Edit")
    nameEdit1:SetWidth({0 , width })
    local itemImg = item:child("Edit_Stage_Item-Img")
    if iconIndex then
        itemImg:SetImage("image/"..self.icons[iconIndex])
    else
        itemImg:SetImage("image/cover.png")
    end
   
    if not test then
        self:subscribe(nameEdit, UIEvent.EventWindowTextChanged, function ()
            CGame.instance:onEditorDataReport("click_stage_rename", "")
            local text = nameEdit:GetPropertyString("Text", "")
            if #text == 0 then
                text = name
                Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("stage_name_empty"), 20)
            end
            name = text --backup
            nameEdit:SetProperty("Text", text)
            stageSetting:renameStage(index, text)
            local width = nameEdit:GetFont():GetTextExtent(name,1.0) + 40
            nameEdit:SetWidth({0 , width })
        end)
        self:subscribe(item:child("Edit_Stage_Item-UpBtn"), UIEvent.EventButtonClick, function ()
            CGame.instance:onEditorDataReport("click_stage_moveup", "")
            self:changeOrder(index, true)
            if isGuide then
                self.addStageBtn:SetName("Stage_Item_add")
            end
        end)
        self:subscribe(item:child("Edit_Stage_Item-DownBtn"), UIEvent.EventButtonClick, function ()
            CGame.instance:onEditorDataReport("click_stage_movedown", "")
            self:changeOrder(index, false)
        end)
    end


    local function controlUi(item, index, test)
        if not item then
            return
        end
        if isGuide and item:child("Stage_Item_Enter") and index ==2 then
            item:child("Stage_Item_Enter"):SetName("Edit_Stage_Item-JumpBtn")
        end
        local bg = item:child("Edit_Stage_Item-bg")
        local delBtn = item:child("Edit_Stage_Item-DeleteBtn")
        local jumpBtn = item:child("Edit_Stage_Item-JumpBtn") or item:child("Stage_Item_Enter")
        local copyBtn = item:child("Edit_Stage_Item-CopyBtn")

        local infoText = item:child("Edit_Stage_Item-Info")
        local nameText = item:child("Edit_Stage_Item-StageName")
        local operation = item:child("Edit_Stage_Item-Operation")
        local orderBg = item:child("Edit_Stage_Item-StageOrder-Bg")
        infoText:SetText(Lang:toText("win.stage.item.info"))
        item:child("Edit_Stage_Item-CopyBtn-text"):SetText(Lang:toText("win.stage.item.copybtn.text"))
        item:child("Edit_Stage_Item-JumpBtn-Text"):SetText(Lang:toText("win.stage.item.enter.text"))
        if World.Lang == "zh_CN" then
            item:child("Edit_Stage_Item-JumpBtn-Text"):SetProperty("TextShadow", "false")
        end
        if not self.listShow then-- need to copy
            nameText:SetText(name)
            nameText:SetVisible(true)
            copyBtn:SetVisible(true)
            operation:SetVisible(false)
        else
            local hideBtn = stageSetting.curStage == index and true or false
            self.curItem = hideBtn and item or self.curItem 
            nameText:SetVisible(false)
            copyBtn:SetVisible(false)
            operation:SetVisible(true)
            infoText:SetVisible(hideBtn)
            if hideBtn then
                bg:SetImage("set:map_edit_stageCurrentBG.json image:bg_stage_current")
            else
                bg:SetImage("set:map_edit_setCheckpoint.json image:bg_item")
                orderBg:SetArea({0.042735, 0}, {0.06, 0}, {0.128205, 0}, {0.381443, 0})
            end
            delBtn:SetVisible(not hideBtn)
            jumpBtn:SetVisible(not hideBtn)
        end
        if not test then
            self:subscribe(delBtn, UIEvent.EventButtonClick, function()
                CGame.instance:onEditorDataReport("click_stage_del", "")
                self.targetDelIndex = index
                self.delTipWin:SetVisible(true)
            end)
            self:unsubscribe(jumpBtn)
            self:subscribe(jumpBtn, UIEvent.EventButtonClick, function()
                CGame.instance:onEditorDataReport("click_stage_jump", "")
                handle_mp_editor_command("save_MpMap", {path = ""})
                local curStage = stageSetting.curStage
                stageSetting:switchStage(index)
                controlUi(self.curItem, curStage, true)
                controlUi(item, index, true)
                if isGuide and index == 2 and item:child("Edit_Stage_Item-UpBtn") then
                    item:child("Edit_Stage_Item-UpBtn"):SetName("Stage_Item-Up")
                end
            end)
            self:subscribe(copyBtn, UIEvent.EventButtonClick, function()
                CGame.instance:onEditorDataReport("click_stage_addnewstage_copymap_copy", "")
                self:addStage(index)
                if isGuide then
                    self.addStageReturnBtn2:SetName("AddStageReturnBtn2")
                end
            end) 
        end
        if index == 2 then
            if isGuide then
                jumpBtn:SetName("Stage_Item_Enter")
            end
        elseif index == 1 then
            if isGuide then
                self.tempItem = item
            end
        end
    end
    controlUi(item, index, test)
end

function M:changeOrder(index, isForward)
    local list = self.listShow and self.stageListShow or self.stageListCopy
    local stages = stageSetting:getStageList()
    local nextIndex = index + (isForward and -1 or 1)
    local curItem = self:fetchItem(index)
    local nextItem = self:fetchItem(nextIndex)
    self:setStageItem(curItem, nextIndex, stages[index], true, index)
    self:setStageItem(nextItem, index, stages[nextIndex], true, nextIndex)
    self.items[index]:SetVisible(false)
    self.items[nextIndex]:SetVisible(false)
    
    local curTargetPos = self.items[nextIndex]:GetYPosition()
    local nextTargetPos = self.items[index]:GetYPosition()

    curItem:SetYPosition(nextTargetPos)
    nextItem:SetYPosition(curTargetPos)
    curItem:SetXPosition(self.items[nextIndex]:GetXPosition())
    nextItem:SetXPosition(self.items[nextIndex]:GetXPosition())

    list:getContainerWindow():AddChildWindow(curItem)
    list:getContainerWindow():AddChildWindow(nextItem)

    Lib.uiTween(curItem, {
        Y = curTargetPos,
    }, 7, function()
    end)
    Lib.uiTween(nextItem, {
        Y = nextTargetPos,
    }, 7, function()
       GUIWindowManager.instance:DestroyGUIWindow(curItem)
       GUIWindowManager.instance:DestroyGUIWindow(nextItem)
       stageSetting:changeStageOrder(index, isForward)
       self:setStageItem( self.items[index], index, stages[nextIndex], true, nextIndex)
       self:setStageItem( self.items[nextIndex], nextIndex, stages[index], true , index)

       self.icons = stageSetting:getStageIconList()

       self.items[index]:SetVisible(true)
       self.items[nextIndex]:SetVisible(true)
    end)
end

function M:closeDeleteTip()
    CGame.instance:onEditorDataReport("click_stage_del_page_cancel", "")
    self.delTipWin:SetVisible(false)
    self.targetDelIndex = nil
end

function M:closeStage()
    CGame.instance:onEditorDataReport("click_stage_close", "")
    UI:closeWnd(self)
end

function M:onOpen()
    self.stageListShow:SetVisible(true)
    self.addStageWin1:SetVisible(false)
    self.addStageWin2:SetVisible(false)
    self.listShow = true
    self:refreshStageList()
end

function M:addStage(index)
    stageSetting:copyStage(index)
end

function M:delStage(index)
    assert(self.targetDelIndex)
    stageSetting:deleteStage(self.targetDelIndex)
    for i = self.targetDelIndex, index - 1 do
        self:adjustList(i) 
    end
    self.items[#self.items-1]:child("Edit_Stage_Item-DownBtn"):SetVisible(false)
    self.items[#self.items-1]:child("Edit_Stage_Item-UpBtn"):SetArea({ 0, 0 }, { -0.167526, 0 }, { 0 , 55 }, { 0 , 55 })
    self.targetDelIndex = nil
    self.items[index] = nil
end

function M:adjustList(index)
    local stages = stageSetting:getStageList()
    self.icons = stageSetting:getStageIconList()
    self:setStageItem( self.items[index], index, stages[index], true, index)
end

function M:onClose()
end

return M
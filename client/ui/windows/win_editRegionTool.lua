-- 编辑UI
M.NotDialogWnd = true
local width = 2
local length = 2
local height = 2
local offsetY = 0

local startPos = false
local endPos = false
local drawBeginPos = Lib.v3(0,0,0)
local drawOverPos = Lib.v3(0,0,0)
local selfPos = Lib.v3(0,0,0)
local function bigAndSmall(a,b)
    if a>b then
        return a+1,b
    else
        return b+1,a
    end
end
DebugDraw.addEntry("editRegionBox", function()
    if not startPos then
        return
    end

    local debugDraw = DebugDraw.instance
    selfPos = Lib.v3(math.floor(Me:getPosition().x),math.floor(Me:getPosition().y),math.floor(Me:getPosition().z))
    drawOverPos.x,drawBeginPos.x =bigAndSmall(endPos and endPos.x or selfPos.x,startPos.x)
    drawOverPos.y,drawBeginPos.y =bigAndSmall(endPos and endPos.y or selfPos.y,startPos.y)
    drawOverPos.z,drawBeginPos.z =bigAndSmall(endPos and endPos.z or selfPos.z,startPos.z) 

    debugDraw:drawAABB(drawBeginPos,drawOverPos)
    

    -- local debugDraw = DebugDraw.instance
    -- local selfPos = Lib.v3(math.floor(Me:getPosition().x),math.floor(Me:getPosition().y),math.floor(Me:getPosition().z))
    -- debugDraw:drawAABB(selfPos-  Lib.v3(width/2,-offsetY+length/2,height/2),selfPos+  Lib.v3(width/2,offsetY+length/2,height/2))
end)
function M:setStartPos(pos)
    startPos = pos
    if not  pos then
        self.txtStartPos:SetText("起始位置未设置")
    else
        self.txtStartPos:SetText("起始位置:"..pos.x..","..pos.y..","..pos.z)
    end
    
end
function M:setEndPos(pos)
    endPos = pos
    if not  pos then
        self.txtEndPos:SetText("结束位置未设置")
    else
        self.txtEndPos:SetText("结束位置:"..pos.x..","..pos.y..","..pos.z)
    end
end
function M:init()
    WinBase.init(self, "EditRegionTool.json",false) 
end

function M:initWnd()

    
    self:child("win_editRegionTool-Pos_c_c"):SetText("地图中的名字：")
    self:child("win_editRegionTool-Pos_c_c_c"):SetText("区域编辑")
    self:child("win_editRegionTool-Pos_c_c_c_c"):SetText("快速位移")
    self:child("win_editRegionTool-Pos_c"):SetText("plugins：")
    

    self.editSize = self:child("win_editRegionTool-Size-Edit")

    self.editType = self:child("win_editRegionTool-Type-Edit")

    self.editName = self:child("win_editRegionTool-Name-Edit")

    self.btnUse = self:child("win_editRegionTool-Use")
    self.btnUse:SetText("到此区域")

    self.btnDel = self:child("win_editRegionTool-Del")
    self.btnDel:SetText("删除")

    self.btnCreate = self:child("win_editRegionTool-Create")
    self.btnCreate:SetText("创建")

    self.btnUp = self:child("win_editRegionTool-Up")
    self.btnDown = self:child("win_editRegionTool-Down")
    self.btnUp:SetText("设为起点")
    self.btnDown:SetText("-")

    self.btnUpGo = self:child("win_editRegionTool-Up-Go")
    self.btnUpGo:SetText("上升")
    self.btnDownGo = self:child("win_editRegionTool-Down-Go")
    self.btnDownGo:SetText("下降")

    self.txtStartPos = self:child("win_editRegionTool-Start-Pos")
    self.txtEndPos = self:child("win_editRegionTool-End-Pos")
    self.txtStartPos:SetText("起始位置未设置")
    self.txtEndPos:SetText("结束位置未设置")

    self.editGoPos = self:child("win_editRegionTool-Pos-Edit")
    self.editGoPos:SetText("0,0,0")
    self.btnGo = self:child("win_editRegionTool-Go")
    self.btnGo:SetText("瞬移")

    self.btnClose = self:child("win_editRegionTool-Close")
    self.btnClose:SetText("退出")
    selfPos = Lib.v3(math.floor(Me:getPosition().x),math.floor(Me:getPosition().y),math.floor(Me:getPosition().z))
end

function M:initValue()
end

function M:initEvent()
    self.btnUpGoRemove = self:subscribe(self.btnUpGo, UIEvent.EventButtonClick, function()
        selfPos = Lib.v3(math.floor(Me:getPosition().x),math.floor(Me:getPosition().y)+1,math.floor(Me:getPosition().z))
        Me:setPosition(selfPos)
        -- Me:sendPacket({
        --     pid = "MoveToPos",
        --     pos = selfPos
        -- })
    end)
    self.btnDownGoRemove = self:subscribe(self.btnDownGo, UIEvent.EventButtonClick, function()
        selfPos = Lib.v3(math.floor(Me:getPosition().x),math.floor(Me:getPosition().y)-1,math.floor(Me:getPosition().z))
        Me:setPosition(selfPos)
        -- Me:sendPacket({
        --     pid = "MoveToPos",
        --     pos = selfPos
        -- })
    end)

    self.btnGoRemove = self:subscribe(self.btnGo, UIEvent.EventButtonClick, function()
        local str = self.editGoPos:GetPropertyString("Text","0,0,0")
        if not string.find(str,',') then
            return
        end
        local sprice = Lib.splitString(str, ",")
        if not sprice[1] or not sprice[2] or not sprice[3] then
            return
        end
        Me:setPosition({
            x = sprice[1],
            y = sprice[2],
            z = sprice[3]
        })
        -- Me:sendPacket({
        --     pid = "MoveToPos",
        --     pos = {
        --         x = sprice[1],
        --         y = sprice[2],
        --         z = sprice[3]
        --     }
        -- })
    end)
    self.btnUseRemove = self:subscribe(self.btnUse, UIEvent.EventButtonClick, function()
        self:gotoEndPos()
        -- local str = self.editSize:GetPropertyString("Text","2,2,2")
        -- if not string.find(str,',') then
        --     return
        -- end
        -- local sprice = Lib.splitString(str, ",")
        -- if not sprice[1] or not sprice[2] or not sprice[3] then
        --     return
        -- end
        -- width = sprice[1]
        -- length = sprice[2]
        -- height = sprice[3]
    end)
    self.btnDelRemove = self:subscribe(self.btnDel, UIEvent.EventButtonClick, function()
        local regionName = self.editName:GetPropertyString("Text","test")
        if regionName == 'test' then
            print("must input regionName ")
            return
        end
        Me:sendPacket({
            pid = "RemoveRegion",
            name = regionName
        })
    end)
    self.btnUpRemove = self:subscribe(self.btnUp, UIEvent.EventButtonClick, function()
        if not startPos then
            self:setStartPos(Lib.v3(math.floor(Me:getPosition().x),math.floor(Me:getPosition().y),math.floor(Me:getPosition().z))) 
            self.btnUp:SetText("设为终点")
            self.btnDown:SetText("取消起点")
        elseif not endPos then
            self:setEndPos(Lib.v3(math.floor(Me:getPosition().x),math.floor(Me:getPosition().y),math.floor(Me:getPosition().z)))
            self.btnUp:SetText("-")
            self.btnDown:SetText("取消终点")
        end
        -- offsetY = offsetY+1
        -- self.txtOffset:SetText("高度偏移量："..(offsetY>0 and "+" or '') ..offsetY)
    end)
    self.btnDownRemove = self:subscribe(self.btnDown, UIEvent.EventButtonClick, function()
        if endPos  then
            self:setEndPos(false)
            self.btnUp:SetText("设为终点")
            self.btnDown:SetText("取消起点")
        elseif startPos then
            self:setStartPos(false)
            self.btnUp:SetText("设为起点")
            self.btnDown:SetText("-")
        end
        -- offsetY = offsetY-1
        -- self.txtOffset:SetText("高度偏移量："..(offsetY>0 and "+" or '') ..offsetY)
    end)

    self.btnCreateRemove = self:subscribe(self.btnCreate, UIEvent.EventButtonClick, function()
        self:writeInMapCfg()
    end)

    self.btnCloseRemove = self:subscribe(self.btnClose, UIEvent.EventButtonClick, function()
        local debugDraw = DebugDraw.instance
        debugDraw:setEnabled(false)
        debugDraw:setDrawRegionEnabled(false)
        debugDraw:setEditRegionBoxEnabled(false)
        UI:closeWnd("editRegionTool", 0)
        Me:setFlyMode(0)
    end)

    
end
function M:gotoEndPos()
    local regionName = self.editName:GetPropertyString("Text","test")
    if regionName == 'test' then
        print("must input regionName ")
        return
    end
    local mapName = Me.map.name
	local filePath = Root.Instance():getGamePath() .. "map/" .. mapName .. "/" .. "setting.json"
    local cfg = assert(Lib.read_json_file(filePath), "gotoEndPos : map setting path error. " .. filePath)
    if not cfg.region or not cfg.region[regionName] then
        return
    end
    local regionCfg = cfg.region[regionName].regionCfg
    local box = cfg.region[regionName].box
    if not regionCfg or not box then
        print("region "..regionName .." regionCfg or box is nil")
        return
    end
    local sprice = Lib.splitString(regionCfg, "/")
    self.editType:SetText(sprice[#sprice])
    
    self:setStartPos(box.min)
    self:setEndPos(box.max)
    self.btnUp:SetText("-")
    self.btnDown:SetText("取消终点")
    -- Me:sendPacket({
    --     pid = "MoveToPos",
    --     pos = box.max
    -- })
    Me:setPosition(box.max)
    
end
function M:writeInMapCfg()

     -- "region": {
    --     "jail": {
    --       "regionCfg": "myplugin/crime_region",
    --       "box": {
    --         "min": {
    --           "x": 227,
    --           "y": 12,
    --           "z": 238
    --         },
    --         "max": {
    --           "x": 265,
    --           "y": 18,
    --           "z": 254
    --         }
    --       }
    --     }
    --   }
    --Me:getPosition()-  Lib.v3(width/2,offsetY+length/2,height/2),Me:getPosition()+  Lib.v3(width/2,offsetY+length/2,height/2))

    local regionName = self.editName:GetPropertyString("Text","test")
    if regionName == 'test' then
        print("must input regionName ")
        return
    end
    local regionCfg = self.editType:GetPropertyString("Text","test")
    if regionCfg == 'test' then
        print("must input regionCfg ")
        return
    end
    if drawBeginPos == Lib.v3(0,0,0) and drawOverPos == Lib.v3(0,0,0) then
        print("must set begin point and end point !")
        return
    end
    local sendParams = {
        name = regionName,
        cfg = regionCfg,
        box ={
            min = {
                x = drawBeginPos.x,
                y = drawBeginPos.y,
                z = drawBeginPos.z,
            },
            max = {
                x = drawOverPos.x-1,
                y = drawOverPos.y-1,
                z = drawOverPos.z-1, 
            }
        }
    }
    print("sendParams:",Lib.v2s(sendParams,3))
    Me:sendPacket({
        pid = "SaveRegion",
        params = sendParams
    })
    self:setStartPos(false)
    self:setEndPos(false)
    self.btnUp:SetText("设为起点")
    self.btnDown:SetText("-")
end

function M:onOpen()
    self:initWnd()
    self:initValue()
    self:initEvent()
end

function M:onClose()
    self:removeEvent()
end

function M:removeEvent()
    if self.btnUpGoRemove then
        self.btnUpGoRemove()
    end
    if self.btnDownGoRemove then
        self.btnDownGoRemove()
    end
    if self.btnGoRemove then
        self.btnGoRemove()
    end
    if self.btnUseRemove then
        self.btnUseRemove()
    end
    if self.btnUpRemove then
        self.btnUpRemove()
    end
    if self.btnDownRemove then
        self.btnDownRemove()
    end
    if self.btnCreateRemove then
        self.btnCreateRemove()
    end
    if self.btnCloseRemove then
        self.btnCloseRemove()
    end
    if self.btnDelRemove then
        self.btnDelRemove()
    end
end
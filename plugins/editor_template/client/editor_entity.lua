--todo 提升破坏方块效率 需求具体绑定某种工具 或 空手 （0-1） 最高效率 破坏时间 1 tick  --默认值0
function Entity.EntityProp:breakEfficient(value, add, buff)
    local data = self:data("efficient")
    data.value = (data.value or 0) + (add and value or -value)
end

function Entity.EntityProp:previewEggBridge(value, add, buff)
    self.lastPreviewEggBridgePos = nil
    self.lastPreviewEggBridgeDx = nil
    self.lastPreviewEggBridgeDz = nil
    local bm = Blockman.instance
	local debugDraw = DebugDraw.instance
    if add then
        if self.previewEggBridgeTimer then
            self.previewEggBridgeTimer()
        end
        local count = World.cfg.bridgeEggBlockCount or 10
        local color = World.cfg.bridgeEggPreviewColor or {1, 1, 0, 0.5}
        self.previewEggBridgeTimer = self:timer(1, function()
            local lastPos = self.lastPreviewEggBridgePos
            local lastDx = self.lastPreviewEggBridgeDx
            local lastDz = self.lastPreviewEggBridgeDz
            local pos = self:getPosition()
            local yaw = self:getRotationYaw() % 360
            local dx, dz = 0, 0
            if 22.5 < yaw and yaw <= 157.5 then
                dx = -1
            elseif yaw <= 337.5 and 202.5 < yaw then
                dx = 1
            end
            if 112.5 < yaw and yaw <= 247.5 then
                dz = -1
            elseif yaw <= 67.5 or 292.5 < yaw then
                dz = 1
            end
            if lastPos and lastPos.x == pos.x and lastPos.y == pos.y and lastPos.z == pos.z and lastDx == dx  and lastDz == dz then
                return true
            end
            bm:clearBlockRenderBoxs()
            self.lastPreviewEggBridgePos = pos
            self.lastPreviewEggBridgeDx = dx
            self.lastPreviewEggBridgeDz = dz
            local mmin, mmax = math.min, math.max
            for i = 1, count do
                local pos1 = (Lib.v3(dx * i, 0, dz * i) + pos):blockPos()
                local pos2 = pos1 + Lib.v3(1, 0, 1)
                local min = Lib.v3(mmin(pos1.x, pos2.x), mmin(pos1.y, pos2.y), mmin(pos1.z, pos2.z))
                local max = Lib.v3(mmax(pos1.x, pos2.x), mmax(pos1.y, pos2.y), mmax(pos1.z, pos2.z))
                bm:setBlockRenderBox(min, max, color)
            end
            debugDraw:setEnabled(true)
            debugDraw:setDrawBlockRenderBoxEnabled(true)
            return true
        end)
    else
        if self.previewEggBridgeTimer then
            self.previewEggBridgeTimer()
            self.previewEggBridgeTimer = nil
        end
        debugDraw:setEnabled(false)
        debugDraw:setDrawBlockRenderBoxEnabled(false)
    end
end
function Entity.EntityProp:openChestCount(value, add, buff)
    local openCount = self.openCount or 0
    local oldCount = openCount
    if add then
        openCount = openCount + 1
        if openCount == 1 then
            self:addClientBuff(buff.cfg.openSound, nil, 100)
            self:setAlwaysAction("open")
        end
    else
        openCount = openCount - 1
        if openCount == 0 then
            self:addClientBuff(buff.cfg.closeSound, nil, 100)
            self:setAlwaysAction("close")
        end
    end
    self.openCount = openCount
end

function Entity.EntityProp:continueDamage(value, add, buff)
	if buff.cfg.initDamage then 
        --onhurt
        self:doHurt(Lib.v3(0,0,0), true)
	end
	
	local continueDamage = self:data("continueDamage")
	continueDamage.damage = (continueDamage.damage or 0) + (add and value or -value)
	if not buff.cfg.calPerSecond then
        --onhurt
        self:doHurt(Lib.v3(0,0,0), true)
	end
	if not continueDamage.timer then
		continueDamage.timer = self:timer(20, function()
            --onhurt
            self:doHurt(Lib.v3(0,0,0), true)
			if continueDamage.damage <= 0 then
				continueDamage.timer = nil
				return false
			end
			return true
		end)
	end
end

function Entity.EntityProp:hide(value, add, cfg, id)
    local prop = self:prop()
    local hide = prop.hide or 0
    local oldHide = hide > 0
    prop.hide = hide + (add and value or -value)
    local newHide = prop.hide > 0
    if oldHide==newHide then
        return
    end
    if not newHide then
        self:setAlpha(1, 10)
    elseif self.isMainPlayer then
        local hideDeep = self:cfg().hideDeep or 0.4
        self:setAlpha(hideDeep, self:cfg().hideTime)
    else
        local hideDeepOther = self:cfg().hideDeepOther or 0.1
        self:setAlpha(hideDeepOther, self:cfg().hideTime)
    end
    self:updateShowName()
    self:timer(2, self.setActorPostionDirty, self, true)
    Lib.emitEvent(Event.CLAC_TEMPORARY_SHIELD, self.objID)
end

--用于商人商店判断物品处于的状态
local statusCheck = {}
function statusCheck:IsEquiping(cond, item)
    for trayType in pairs(item:tray_type()) do
        if trayType ~= 0 then
            local trays = Me:tray():query_trays(trayType)
            for _, element in pairs(trays) do
                local items = element.tray:query_items(function(_item)
                    return _item:full_name() == item:full_name()
                end)
                if next(items) then
                    return true, "being_used"
                end
            end
        end
    end
    return false
end

function statusCheck:IsUsing(cond, item)
    local selfBuffTb = Me._selfBuffTb or {}
    local teamBuffTb = Me._teamBuffTb or {}
    local cfg = item:cfg()
    local attachBuff = cfg.attachBuff
    for _, v in pairs(selfBuffTb) do
        if v == attachBuff then
            return true, "being_used"
        end
    end
    for _, v in pairs(teamBuffTb) do
        if v == attachBuff then
            return true, "being_used"
        end
    end
    return false
end

function Entity:updateEquipBuffList(data)
    if data.selfBuffTb then
        self._selfBuffTb = data.selfBuffTb
    end
    if data.teamBuffTb then
        self._teamBuffTb = data.teamBuffTb
    end
	Lib.emitEvent(Event.EVENT_UPDATE_CUR_ITEM_VIEW, data)
end

function Entity:checkGoodsStatus(cond, ...)
    local func = statusCheck[cond.funcName]
    if not func then
        return
    end
    return func(self, cond, ...)
end

function Entity:checkCanCastClick(packet, from)
    local ret = true
    local selfCfg = self:cfg()
    local checkClickFuncName = selfCfg.checkClickFuncName
    if self[checkClickFuncName] then
        ret = self[checkClickFuncName](self)
    end
    return ret
end

function Entity:showMerchantShop()
    local selfCfg = self:cfg()
    UI:openWnd("merchantstores", selfCfg.groupIndex, selfCfg.showTitle)
    return false
end
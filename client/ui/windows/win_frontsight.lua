local setting = require "common.setting"
local lfs   = require "lfs"
local frontSightTab = L("frontSightTab",{})
local imageTab = L("imageTab",{})
local circleTab = L("circleTab",{})
local currenFs = L("currenFs",{})
local _onlyFpShow = L("_onlyFpShow",nil)
local stop = L("stop",nil)

local function hideFeedbackImage(self)
    if self.alphaTimer then
        self.alphaTimer()
    end
    local cfg = Me:cfg().attackFeedback
    local totalTime = cfg.hideTime or 10
    self.timeLeft = totalTime
    self.alphaTimer = World.Timer(1, function()
        self.timeLeft = self.timeLeft - 1
        if self.timeLeft > 0 then
            if cfg.hideSmooth ~= false then
                self.fb_image:SetAlpha(self.timeLeft/totalTime)
            end
            return true
        else
            self.fb_image:SetAlpha(0)
            self.fb_image:SetVisible(false)
            return false
        end
    end)
end

local function hitEntityFeedback(self, packet)
    local cfg = Me:cfg().attackFeedback
    if not cfg then
        return
    end
    if cfg.hitPlayer == false and packet.target:isControl() then
        return
    end
    if cfg.hitNpc == false and not packet.target:isControl() then
        return
    end
    local hidHeadImage = cfg.hitHeadImage or "set:attack_effect.json image:hit_head.png"
    local hidBodyImage = cfg.hidBodyImage or "set:attack_effect.json image:hit_body.png"
    self.fb_image:SetImage(packet.headHit and hidHeadImage or hidBodyImage)
    self.fb_image:SetVisible(true)
    self.fb_image:SetAlpha(1)
    hideFeedbackImage(self)
end

function M:init()
    WinBase.init(self, "FrontSight.json")
    self.fb_image = self:child("Crosshair-Hit-Feedback")

    Lib.lightSubscribeEvent("error!!!!! : win_frontsight lib event : CREATE_FRONTSIGHT", Event.CREATE_FRONTSIGHT, function(instance)
		self:create(instance)
	end)
    Lib.lightSubscribeEvent("error!!!!! : win_frontsight lib event : DESTROY_FRONTSIGHT", Event.DESTROY_FRONTSIGHT, function()
		self:destroy()
	end)
    Lib.lightSubscribeEvent("error!!!!! : win_frontsight lib event : DIFFUSE_FRONTSIGHT", Event.DIFFUSE_FRONTSIGHT, function(diffuse)
        local currenCfg = currenFs[1] 
        if currenCfg then
            diffuse = diffuse or currenCfg.moveDiffuse
		    self:diffuse(diffuse, 1)
            self:Shrink(diffuse)
        end
	end)

    Lib.lightSubscribeEvent("error!!!!! : win_frontsight lib event : FRONTSIGHT_NOT_SHOW", Event.FRONTSIGHT_NOT_SHOW, function()
        self:notShow()
	end)

    Lib.lightSubscribeEvent("error!!!!! : win_frontsight lib event : FRONTSIGHT_SHOW", Event.FRONTSIGHT_SHOW, function()
        self:show()
	end)

	Lib.lightSubscribeEvent("error!!!!! : win_frontsight lib event : CHECK_HIT", Event.CHECK_HIT, function(hitObj)
		self:checkHit(hitObj)
	end)

    Lib.lightSubscribeEvent("error!!!!! : win_frontsight lib event : EVENT_ON_HIT_ENTITY", Event.EVENT_ON_HIT_ENTITY, function(packet)
        hitEntityFeedback(self, packet)
    end)
    Lib.lightSubscribeEvent("error!!!!! : win_frontsight lib event : SKILL_RELOAD", Event.SKILL_RELOAD, function(isCancel)
        self:reloadFeedBack(isCancel)
    end)
end

local function resetFSImg()
    local currenCfg = currenFs[1]
    if not currenCfg or not currenCfg.hitEntityImgs then
        return
    end
    local imgCfg
    for _, v in pairs(currenCfg.List) do
        if v.type == "Image" then
            imgCfg = v.Image
        end
    end
    if not imgCfg then
        return
    end
    for i,v in ipairs(imageTab[1])do
        if imgCfg[i] then
            local imagePath = ResLoader:filePathJoint(currenCfg, imgCfg[i].path)
            v:SetImage(imagePath)
        end
    end
end

function M:reloadFeedBack(isCancel)
    if circleTab[1] then
        for i,v in ipairs(circleTab[1])do
            v:SetVisible(true)
            v:invoke("playMask")
        end
    end
end

function M:create(instance)
    local from = instance.from
    local cfg = instance.cfg
    if frontSightTab[1] or currenFs[1] then
        self._root:RemoveChildWindow1(frontSightTab[1])
        frontSightTab[1] = nil
        currenFs[1] = nil
    end
    local frontSightInstance = GUIWindowManager.instance:CreateGUIWindow1("Layout", "FrontSight" .. tostring(from))
    frontSightTab[1] = frontSightInstance
    currenFs[1] = cfg
    self._root:AddChildWindow(frontSightInstance)
    frontSightInstance:SetArea({ 0, 0 }, { 0,  0}, { 1, 0 }, { 1, 0})
    frontSightInstance:SetEnabled(false)
    for i,v in pairs(cfg.List or {})do
        if v.type=="Image" then
            self:drawFrontSightByImage(v, cfg, from)
        elseif v.type=="Ccircle" then
            self:drawFrontSightByCircle(v, from)
        end
    end
    if cfg.onlyFpShow then
        _onlyFpShow = cfg.onlyFpShow
        local view = Blockman.Instance():getCurrPersonView()
        if view~=0 then
            self:notShow(2)
        end
    end
    self.reloadArg = table.pack(instance)
    --切镜时重新打开准心
    self:show()
end

function M:notShow()
    self._root:SetVisible(false)
end

function M:show()
	local view = Blockman.Instance():getCurrPersonView()
	if _onlyFpShow then
		if view==0 then
			self._root:SetVisible(true)
		else
			self._root:SetVisible(false)
		end
	else
		self._root:SetVisible(true)
	end
end

function M:destroy(fullName)
    if frontSightTab[1] then
        local destroy = frontSightTab[1]
        self._root:RemoveChildWindow1(destroy)
        frontSightTab[1] = nil
        currenFs[1] = nil
		imageTab[1] = nil
    end
    if stop then
        stop()
    end
end

function M:drawFrontSightByImage(imageFrontSight, frontSightCfg, fullName)
    for i,v in pairs(imageFrontSight.Image)do
        local initPos = v.initPos
        local imagePath = ResLoader:filePathJoint(frontSightCfg, v.path)
        local frontSight = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "FrontSight" .. tostring(imagePath))
        local imageSize = TextureManager.Instance():getImageWidthAndHeight(imagePath)
        if imageSize.x == -1 or imageSize.y == -1 then 
            World.Timer(2, function()
                self:onReload(self.reloadArg)
            end)
            break
        end
        frontSight:SetHorizontalAlignment(1)
        frontSight:SetVerticalAlignment(1)
        frontSight:SetArea({ 0, initPos.x }, { 0,  initPos.y}, {  0, v.width or imageSize.x }, { 0, v.height or imageSize.y})
        frontSight:SetImage(imagePath)
        frontSightTab[1]:AddChildWindow(frontSight)
        imageTab[1] = imageTab[1] or {}
        table.insert(imageTab[1], frontSight)
    end
end

function M:drawFrontSightByCircle(circleFrontSightVal)
    local circleFrontSight = UIMgr:new_widget("circel")
	frontSightTab[1]:AddChildWindow(circleFrontSight)
	circleFrontSight:invoke("setRadius", circleFrontSightVal.init_r)
    if circleFrontSightVal.commonColor then
        local commonColor = circleFrontSightVal.commonColor
        circleFrontSight:invoke("setColor", commonColor.r, commonColor.g, commonColor.b, commonColor.a)
    end
    circleTab[1] = circleTab[1] or {}
    table.insert(circleTab[1], circleFrontSight)
end

function M:Shrink(diffuseVal)
    local currenCfg = currenFs[1]
    if not currenCfg or not diffuseVal then
        return
    end
    local shrinkVal = currenCfg.shrinkVal
    local diffuse = diffuseVal
    local function tick()
        diffuse = diffuse - shrinkVal or 1
        if diffuse < currenCfg.minDiffuse then
            return false
        end
        self:diffuse(shrinkVal, 2)
       return true
    end
    stop = World.Timer(0, tick)
end

function M:diffuse(diffuse,type)
    local currenCfg = currenFs[1]
    if not currenCfg or not diffuse then
        return
    end
    if diffuse<=0 then
        return
    end
    if diffuse >= currenCfg.maxDiffuse then
        return
    end
    local toMove = 0
    local minDiffuse = currenCfg.minDiffuse
    if type==1 then
        toMove = diffuse - minDiffuse
    end
    if type==2 then
        toMove = (-diffuse)
    end
    if imageTab[1] then
        --Image
        for i,v in ipairs(imageTab[1])do
            local x = v:GetXPosition()
            local y = v:GetYPosition()
            --在轴上的四种情况
            if x[2]==0 and y[2]<0 then
                v:SetYPosition({0,y[2] + (-toMove)})
            end
            if x[2]==0 and y[2]>0 then
                v:SetYPosition({0,y[2] + toMove})
            end
            if x[2]<0 and y[2]==0 then
                v:SetXPosition({0,x[2] + (-toMove)})
            end
            if x[2]>0 and y[2]==0 then
                v:SetXPosition({0,x[2] + toMove})
            end
            --在象限内的四种情况
            if x[2]<0 and y[2]<0 then
                v:SetXPosition({0,x[2] + (-toMove)})
                v:SetYPosition({0,y[2] + (-toMove)})
            end
            if x[2]>0 and y[2]<0 then
                v:SetXPosition({0,x[2] + toMove})
                v:SetYPosition({0,y[2] + (-toMove)})
            end
            if x[2]<0 and y[2]>0 then
                v:SetXPosition({0,x[2] + (-toMove)})
                v:SetYPosition({0,y[2] + toMove})
            end
            if x[2]>0 and y[2]>0 then
                v:SetXPosition({0,x[2] + toMove})
                v:SetYPosition({0,y[2] + toMove})
            end
        end
    end
    if circleTab[1] then
        for i,v in ipairs(circleTab[1])do
            v:invoke("incrRadius", toMove)
        end
    end
end

function M:checkHit(hitObj)
	local _type = hitObj._type
	local friend = hitObj.friend
	local currenCfg = currenFs[1]
	if not currenCfg or not imageTab or not imageTab[1] then
		return
	end
	local images = {}
	for i,v in pairs(currenCfg.List)do
		if v.type == "Image" then
			images = v.Image
			break
		end
	end
	if  _type=="MISS" or not hitObj.canAttackTarget then
        for j,k in ipairs(imageTab[1])do
            if j <= #images then
                local imagePath = ResLoader:filePathJoint(currenFs[1], images[j].path)
                k:SetImage(imagePath)
            end
		end
	elseif _type=="ENTITY" and friend then
		for j,k in ipairs(imageTab[1])do
            if j <= #images then
                local imagePath = ResLoader:filePathJoint(currenFs[1], images[j].hitFriendlyPath or images[j].path)
                k:SetImage(imagePath)
            end
		end
	elseif _type=="BLOCK" or _type=="ENTITY" then
		for j,k in ipairs(imageTab[1])do
            if j <= #images then
                local imagePath = ResLoader:filePathJoint(currenFs[1], images[j].hitPath or images[j].path)
                k:SetImage(imagePath)
            end
		end
	end
end

function M:onReload(reloadArg)
    local _instance = table.unpack(reloadArg or {}, 1, reloadArg and reloadArg.n)
	self:create(_instance)
end

return M

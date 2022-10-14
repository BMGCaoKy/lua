local hpImage = L("hpImage", nil)
local vpImage = L("vpImage", nil)
local headIconFrame = L("headIconFrame", nil)
local _headInfoBg = L("headInfoBg", nil)

function M:init()
	WinBase.init(self, "Entity_HeadInfo.json", true)
	self.headIcon = self:child("Entity-headinfo-head_icon")				--头像
	self.headIconFrame = self:child("Entity-headinfo-headIconFrame")	--头像框
	self.level = self:child("Entity-headinfo-level")					--等级
	self.name = self:child("Entity-headinfo-name")						--名字
	self.hpBg = self:child("Entity-headinfo-hp-bg")						--血条背景框
	self.hpValue = self:child("Entity-headinfo-curHp-value")			--当前血条
	self.nextHpValue = self:child("Entity-headinfo-next-hp-image")		--下一个血条（血条叠加时）
	self.vpBg = self:child("Entity-headinfo-vp-bg")						--体力背景框
	self.vpValue = self:child("Entity-headinfo-vp-value")				--当前体力
	self.nextVpValue = self:child("Entity-headinfo-next-vp-image")		--下一个体力（体力叠加时）
	self.headInfoBg = self:child("Entitiy-headinfo-bg")					--头顶信息背景框
	self.showHpText = self:child("Entity-headinfo-show-hp-text")		--显示血条叠加数字
	self.showVpText = self:child("Entity-headinfo-show-vp-text")		--显示体力条叠加数字
end

function M:onOpen(packet)
	local headInfo = packet.headInfo
	local headInfoPos = headInfo.headInfoPos
	local entity = World.CurWorld:getEntity(packet.objID)
	if headInfoPos and next(headInfoPos) then
		self:root():SetXPosition({0,headInfoPos.x})
		self:root():SetYPosition({0,headInfoPos.y})
	end
	--头像
	self:setHeadIcon(entity, headInfo.headIcon)
	--头像框大小位置
	self:setIconFeame(headInfo.headIconFrame)
	--背景框大小位置
	self:setHeadInfoBg(headInfo.headInfoBg)
	--名字
	self.name:SetText(headInfo.showName and entity.name or "")
	--血条
	self:setHpInvolved(headInfo.hpInvolved)
	--体力
	self:setVpInvolved(headInfo.vpInvolved)
	--更新血量 体力 头像框 背景框 等级
	self:updataHeadInfo(entity, headInfo)
end

function M:setHeadIcon(entity, head_icon)
	if head_icon and next(head_icon) then
		local head_icon_from = head_icon.path
		local size = head_icon.size
		local pos = head_icon.pos
		local headIcon = self.headIcon
		if size then
			headIcon:SetWidth({0, size.w})
			headIcon:SetHeight({0, size.h})
		end
		if pos then
			headIcon:SetXPosition({0, pos.x})
			headIcon:SetYPosition({0, pos.y})
		end
		if entity.isPlayer then
			if head_icon_from == "platform" then
				AsyncProcess.GetUserDetail(Me.platformUserId, function (data)
				    if data and data.picUrl and #data.picUrl > 0  then
				        headIcon:SetImageUrl(data.picUrl)
				    end
				end)
			else
				headIcon:SetImage(head_icon_from)
			end
		else
			headIcon:SetImage(head_icon_from)
		end
		if head_icon.cutRadius then
			headIcon:setCircleCut(head_icon.cutRadius)
		end
	else
		return
	end
end

function M:setIconFeame(headIcon_Frame)
	if headIcon_Frame and next(headIcon_Frame)then
		local size = headIcon_Frame.size
		local pos = headIcon_Frame.pos
		local headIconFrame = self.headIconFrame
		if size then
			headIconFrame:SetWidth({0, size.w})
			headIconFrame:SetHeight({0, size.h})
		end
		if pos then
			headIconFrame:SetXPosition({0, pos.x})
			headIconFrame:SetYPosition({0, pos.y})
		end
	else
		return
	end
end

function M:setHeadInfoBg(headInfo_Bg)
	if headInfo_Bg and next(headInfo_Bg)then
		local size = headInfo_Bg.size
		local pos = headInfo_Bg.pos
		local headInfoBg = self.headInfoBg
		if size then
			headInfoBg:SetWidth({0, size.w})
			headInfoBg:SetHeight({0, size.h})
		end
		if pos then
			headInfoBg:SetXPosition({0,pos.x})
			headInfoBg:SetYPosition({0,pos.y})
		end
	else
		return
	end
end

function M:setHpInvolved(hpInvolved)
	if hpInvolved and next(hpInvolved) then
		local hp_BgSize = hpInvolved.bgSize
		local hp_Size = hpInvolved.hpSize
		local hp_pos = hpInvolved.pos
		local hp_BgNineGird = hpInvolved.bgNineGird
		local hp_NineGird = hpInvolved.hpNineGird
		local hpBg = self.hpBg
		local curHpImage = self.hpValue
		local nextHpImage = self.nextHpValue
		hpBg:SetBackImage(hpInvolved.bg or "")
		if hp_BgSize then
			hpBg:SetWidth({0, hp_BgSize.w})
			hpBg:SetHeight({0, hp_BgSize.h})
		end
		if hp_Size then
			curHpImage:SetWidth({0, hp_Size.w})
			curHpImage:SetHeight({0, hp_Size.h})
			nextHpImage:SetWidth({0, hp_Size.w})
			nextHpImage:SetHeight({0, hp_Size.h})
		end
		if hp_pos then
			hpBg:SetXPosition({0, hp_pos.x})
			hpBg:SetYPosition({0, hp_pos.y})
		end

		if hp_BgNineGird then
			hpBg:SetProperty("StretchType", "NineGrid")
			hpBg:SetProperty("StretchOffset", hp_BgNineGird)
		end

		if hp_NineGird then
			curHpImage:SetProperty("StretchType", "NineGrid")
			curHpImage:SetProperty("StretchOffset", hp_NineGird)
			nextHpImage:SetProperty("StretchType", "NineGrid")
			nextHpImage:SetProperty("StretchOffset", hp_NineGird)
		end
	else
		return
	end
end

function M:setVpInvolved(vpInvolved)
	if vpInvolved and next(vpInvolved) then
		local vp_BgSize = vpInvolved.bgSize
		local vp_Size = vpInvolved.vpSize
		local vp_pos = vpInvolved.pos
		local vp_BgNineGird = vpInvolved.bgNineGird
		local vp_NineGird = vpInvolved.vpNineGird
		local vpBg = self.vpBg
		local curVpImage = self.vpValue
		local nextVpImage = self.nextVpValue
		vpBg:SetBackImage(vpInvolved.bg or "")
		if vp_BgSize then
			vpBg:SetWidth({0, vp_BgSize.w})
			vpBg:SetHeight({0, vp_BgSize.h})
		end
		if vp_Size then
			curVpImage:SetWidth({0, vp_Size.w})
			curVpImage:SetHeight({0, vp_Size.h})
			nextVpImage:SetWidth({0, vp_Size.w})
			nextVpImage:SetHeight({0, vp_Size.h})
		end
		if vp_pos then
			vpBg:SetXPosition({0, vp_pos.x})
			vpBg:SetYPosition({0, vp_pos.y})
		end
		if vp_BgNineGird then
			vpBg:SetProperty("StretchType", "NineGrid")
			vpBg:SetProperty("StretchOffset", vp_BgNineGird)
		end

		if vp_NineGird then
			curVpImage:SetProperty("StretchType", "NineGrid")
			curVpImage:SetProperty("StretchOffset", vp_NineGird)
			nextVpImage:SetProperty("StretchType", "NineGrid")
			nextVpImage:SetProperty("StretchOffset", vp_NineGird)
		end
	else
		return
	end
end

function M:updataHeadInfo(entity, headInfo)
	local hpStake = headInfo.hpStake or {}
	local vpStake = headInfo.vpStake or {}
	local updataHp = hpStake and next(hpStake)
	local updataVp = vpStake and next(vpStake)
	local changeHpimageValue
	local changeVpimageValue
	headIconFrame = headInfo.headIconFrame and headInfo.headIconFrame.path
	_headInfoBg = headInfo.headInfoBg and headInfo.headInfoBg.path
	
	self.headIconFrame:SetImage(headIconFrame or "")
	self.headInfoBg:SetImage(_headInfoBg or "")
	Lib.subscribeEvent(Event.EVENT_HEADINFO_CHANGE, function(headInfo)
		hpImage = headInfo.hpImage
		vpImage = headInfo.vpImage
		headIconFrame = headInfo.headIconFrame
		_headInfoBg = headInfo.headInfoBg
		
		self.headIconFrame:SetImage(headIconFrame or "")
		self.headInfoBg:SetImage(_headInfoBg or "")
	end)

	self:setHeadInfoBg(headInfo.headInfoBg)
	local hpImages = hpStake and hpStake.images
	local vpImages = vpStake and vpStake.images
	local function tick()
		--------------------------------------TICK_HP---------------------------------------
		if entity and entity:isValid() then
			if updataHp then
				local maxHp = entity:prop("maxHp")
				local curHp = entity.curHp
				changeHpimageValue = maxHp / hpStake.count
				local curHpStake = curHp // changeHpimageValue
				local curHpImageIndex = math.floor((maxHp-curHp + 1)/changeHpimageValue)
				curHpImageIndex = curHpImageIndex % #hpImages + 1

				local curHpImage = ""
				if hpImage~=nil then
					curHpImage = hpImage
				else
					curHpImage = hpImages[curHpImageIndex]
				end
				self.hpValue:SetProgressImage(curHpImage)
				local nextHpImage = ""
				if curHp >= changeHpimageValue then
					self.showHpText:SetText("X"..math.floor(curHp/changeHpimageValue))
					if hpStake.stakeTextSzie then
						self.showHpText:SetFontSize("HT"..hpStake.stakeTextSzie)
					end
					if hpImages[curHpImageIndex + 1] then
						nextHpImage = hpImages[curHpImageIndex + 1]
					else
						nextHpImage = hpImages[1]
					end
				else
					self.showHpText:SetText("")
					self.nextHpValue:SetImage("")
				end
				self.nextHpValue:SetImage(nextHpImage)

				local cur_hp =  curHp % changeHpimageValue
				cur_hp = curHp <= changeHpimageValue and cur_hp or (cur_hp == 0 and changeHpimageValue or    cur_hp)
				self.hpValue:SetProgress(cur_hp / changeHpimageValue)
			end

			--------------------------------------TICK_VP---------------------------------------
			if updataVp then
				local maxVp = entity:prop("maxVp")
				local curVp = entity.curVp
				changeVpimageValue = maxVp / vpStake.count
				local curVpStake = curVp // changeVpimageValue
				local curVpImageIndex = curVpStake + (curVp % changeVpimageValue == 0 and 0 or 1)
				curVpImageIndex = vpStake.count + 1 - curVpImageIndex
				local curVpImage = ""
				if vpImage~=nil then
					curVpImage = vpImage
				elseif vpImages[curVpImageIndex] then
					curVpImage = vpImages[curVpImageIndex]
				else
					curVpImage = vpImages[1]
					curVpImageIndex = 1
				end
				self.vpValue:SetProgressImage(curVpImage)
				local nextVpImage = ""
				if curVp >= changeVpimageValue then
					self.showVpText:SetText("X"..math.ceil(curVpStake))
					if vpImages[curVpImageIndex + 1] then
						nextVpImage = vpImages[curVpImageIndex + 1]
					else
						nextVpImage = vpImages[1]
					end
				else
					self.showVpText:SetText("")
					self.nextVpValue:SetImage("")
				end
				self.nextVpValue:SetImage(nextVpImage)
				local cur_vp = curVp % changeVpimageValue
				cur_hp = curVp <= changeVpimageValue and cur_vp or (cur_vp == 0 and changeVpimageValue or    cur_vp)
				self.vpValue:SetProgress(cur_vp / changeVpimageValue)
			end

			--------------------------------------TICK_LEVEL---------------------------------------
			self.level:SetText(headInfo.showLevel and "Lv."..entity:getValue("level") or "")
		end
	    return true
	end
	World.Timer(2, tick)
end

return M

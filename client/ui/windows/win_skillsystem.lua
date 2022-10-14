
local equipSkillBarNum = 0
local function fetchCell()
	return UIMgr:new_widget("cell","widget_skill_cell.json","widget_skill_cell")
end

local function getIcon(cfg) 
	if type(cfg.icon)~="string" then
		return nil
	end
	if not cfg.iconPath then
		cfg.iconPath = ResLoader:loadImage(cfg, cfg.icon)
	end
	return cfg.iconPath
end

function M:init()
	self.objID = Me.objID
	WinBase.init(self, "SkillSystemBase.json", true)
    
    local skillJack = World.cfg.skillJack or {}
    for _, jackInfo in ipairs(skillJack.sectorSkills or {}) do
        equipSkillBarNum = equipSkillBarNum + jackInfo.jackNum
    end

    self:initSkillWnd()
	self:initSureEquipWnd()
end

function M:initSkillWnd()
	self.wndSkill = self:child("SkillSystemBase-Skill_Base")
	self:initCellGridView()

	self:child("SkillSystemBase-Active_Skill_Top_Bar_Text"):SetText(Lang:toText("skillsystem.active.skill"))
	self:child("SkillSystemBase-Pastive_Skill_Top_Bar_Text"):SetText(Lang:toText("skillsystem.pastive.skill"))
	self:child("SkillSystemBase-Top_Bar_Text"):SetText(Lang:toText("skillsystem.effect.description"))


	--注册 使用 按钮
	local btnUseSkill = self:child("SkillSystemBase-Use_Btn")
	self:subscribe(btnUseSkill, UIEvent.EventButtonClick, function() self:onClickUseSkill() end)
	self.btnUseSkill = btnUseSkill
	self:child("SkillSystemBase-Use_Btn_Text"):SetText(Lang:toText("skillsystem.use.skill"))


	-- 注册右边技能描述相关
	self.skillIconGroove = self:child("SkillSystemBase-Icon_Groove_Base")
	self.skillIconView = self:child("SkillSystemBase-Icon_Groove_View")
	self.skillIconName = self:child("SkillSystemBase-Icon_Name_Text")
	self.skillExplain = self:child("SkillSystemBase-Explain_Bar_Text")

end

function M:initCellGridView()
	local gvActiveBag = self:child("SkillSystemBase-Active_Base_Skill_Bar")
	self.gvActiveBag = gvActiveBag
	self:initSkillCellGridView(gvActiveBag)

	local gvPassiveBag = self:child("SkillSystemBase-Pastive_Base_Skill_Bar")
	self.gvPassiveBag = gvPassiveBag
	self:initSkillCellGridView(gvPassiveBag)
end

function M:initSkillCellGridView(gv)
	gv:InitConfig(0, 0, 6)
	gv:HasItemHidden(false)
	gv:SetMoveAble(true)
	local newSize = gv:GetPixelSize().y / 2
	for i = 1, 12 do
		local cell = fetchCell()
		cell:SetArea({ 0, 0 }, { 0, 0 }, { -0.025, newSize}, { -0.025, newSize})
		cell:setData("index", i)
		gv:AddItem(cell)
	end
end

function M:onClickUseSkill()
	if not self.selectedSkill then
		return
	end
	self:resetEquipSkillBar()
	self.sureEquipBase:SetVisible(true)
end

function M:resetSelectedSkill(cfg)
	self.selectedSkill = cfg

	self.skillIconGroove:SetVisible(cfg and true or false)
	self.skillIconView:SetImage(cfg and getIcon(cfg) or nil)
	self.skillIconName:SetText(cfg and Lang:toText(cfg.name) or "")
	self.skillExplain:SetText(cfg and Lang:toText(cfg.desc) or "")

	self.btnUseSkill:SetVisible(cfg and cfg.isActive or false)
end

function M:initSureEquipWnd()
	local sureEquipBase = GUIWindowManager.instance:LoadWindowFromJSON("SkillSystemPopups.json")
	self.sureEquipBase = sureEquipBase
	self.wndSkill:AddChildWindow(sureEquipBase)
	sureEquipBase:SetLevel(8)

	local function setCurWndVisiable(isOpen)
		self.sureEquipBase:SetVisible(isOpen)
	end

	local sureEquipBaseEvent = sureEquipBase:child("SkillSystemPopups-Base")
	self:subscribe(sureEquipBaseEvent, UIEvent.EventWindowClick, function()
		setCurWndVisiable(false)
	end)

	self:initEquipSkillBar()

	sureEquipBase:child("SkillSystemPopups-Sure_Btn_Text"):SetText(Lang:toText("sure"))
	local btnSure = sureEquipBase:child("SkillSystemPopups-Sure_Btn")
	self:subscribe(btnSure, UIEvent.EventButtonClick, function()
		local selectedSkill = self.selectedSkill
		if not selectedSkill then
			return
		end
        Me:equipSkill(self.equipSkillBar or 1, selectedSkill)
--		Me:sendPacket({	pid = "EquipSkill", 
--							objID = Me.objID,
--							equipSkillBar = self.equipSkillBar or 1, 
--							equipSkill = selectedSkill })
		-- local data = Me:data("skill")
		-- data.equipSkills = data.equipSkills or {}
		-- data.equipSkills[self.equipSkillBar or 1] = selectedSkill.fullName

		for c,i in pairs(self.cells or {}) do
			c:invoke("RESET_OUTER_FRAME", false)
		end

		self:resetSelectedSkill()
		setCurWndVisiable(false)
	end)
	setCurWndVisiable(false)
end

function M:initEquipSkillBar()
	local sureEquipBarBase = self.sureEquipBase:child("SkillSystemPopups-Bar_Base")
	self.sureEquipBarGv = {}
	local sureEquipBarGv = self.sureEquipBarGv
	local gvX,gvY = sureEquipBarBase:GetPixelSize().x,sureEquipBarBase:GetPixelSize().y
	for i=1,equipSkillBarNum do
		local bar = GUIWindowManager.instance:LoadWindowFromJSON("SkillSystemPopupsBar.json")
		sureEquipBarGv[i] = bar
		local barX,barY = bar:GetPixelSize().x,bar:GetPixelSize().y
		bar:child("SkillSystemPopupsBar-Base_Text"):SetText(Lang:toText("skillsystem.equip.skill.bar." .. i))
		local skillBarBtn = bar:child("SkillSystemPopupsBar-Base_Btn") -- TODO : 交换技能
		self:subscribe(skillBarBtn, UIEvent.EventButtonClick,function() 
			if self.equipSkillBar then
				sureEquipBarGv[self.equipSkillBar]:child("SkillSystemPopupsBar-Base_Frame"):SetVisible(false)
			end
			self.equipSkillBar = i 
			bar:child("SkillSystemPopupsBar-Base_Frame"):SetVisible(true)
		end)
		bar:SetArea({0,gvX/(equipSkillBarNum+1) * i - barX/2},{0,gvY/2 - barY/2},{0,barX},{0,barY})
		sureEquipBarBase:AddChildWindow(bar)
	end

	self:resetEquipSkillBar()
end

function M:resetEquipSkillBar()
	local gv = self.sureEquipBarGv
	local studySkillMap = Me:data("skill").studySkillMap or {}
	local skillMap = studySkillMap.studySkills or {}
	local equipSkills = studySkillMap.equipSkills or {}

	for i=1,equipSkillBarNum do
		local cell = gv[i]
		cell:child("SkillSystemPopupsBar-Base_Frame"):SetVisible(false)
		local fullName = equipSkills[i]
		local skillBarIcon = cell:child("SkillSystemPopupsBar-Base_Icon") 
		if fullName and skillMap[fullName] then
			skillBarIcon:SetImage(Skill.Cfg(fullName):getIcon())
		else
			skillBarIcon:SetImage("")
		end
	end
end

function M:onOpen(packet) -- 打开技能面板
	local isMe = packet.isMe
	self.parentUi = packet.parentUi
	self._root:SetWidth({1, 0})
	self._root:SetVisible(true)
	self.wndSkill:SetVisible(isMe)
	if isMe then
		self:resetSkillsView()
	end
end

function M:onClose()
	local num = self.parentUi:GetChildCount()
	for i = 1, num do
		local win = self.parentUi:GetChildByIndex(i - 1)
		win:SetVisible(false)
		self.parentUi:RemoveChildWindow(win)
	end
	self.sureEquipBase:SetVisible(false)
	WinBase.onClose(self)
end

function M:resetSkillsView() 
	local gvActiveBag = self.gvActiveBag
	self:resetSkillView(gvActiveBag)
	local gvPassiveBag = self.gvPassiveBag
	self:resetSkillView(gvPassiveBag)
	
	self:showSkillsView()
	self:resetSelectedSkill()
end

function M:resetSkillView(gv)
	for i = 0, gv:GetItemCount() - 1 do
        local cell = gv:GetItem(i)
        if cell then
			cell:invoke("RESET")
			cell:SetName("")
			cell:invoke("SHOW_LOCKED", true)
			cell:invoke("RESET_OUTER_FRAME", false)
			self:unsubscribe(cell)
        end
    end
end

local function getActiveAndPassiveSkills()
	local actives = {}
	local passives = {}
	local data = Me:data("skill")
	local skillMap = data.studySkillMap and data.studySkillMap.studySkills or {} 
	for name in pairs(skillMap) do
		local skillCfg = Skill.Cfg(name)
		if skillCfg.isActive then
			actives[#actives + 1] = skillCfg
		end
		if skillCfg.isPassive then
			passives[#passives + 1] = skillCfg
		end
	end
	return actives,passives
end

function M:showSkillsView() 
	local activeSkills,passiveSkills = getActiveAndPassiveSkills()

	local function unlockCell(cell, cfg)
		cell:invoke("SHOW_LOCKED", false)
		cell:invoke("SET_ICON_BY_PATH", getIcon(cfg))
		self:subscribe(cell, UIEvent.EventWindowClick, 
			function() 
				self:resetSelectedSkill(cfg) 
				for c,i in pairs(self.cells  or {}) do
					c:invoke("RESET_OUTER_FRAME", false)
				end
				cell:invoke("RESET_OUTER_FRAME", true)
			end)
	end
	local cells = {}
	self.cells = cells
	for i,cfg in pairs(activeSkills) do
		local idx = 0
		local cell = self.gvActiveBag:GetItem(i - 1)
		cells[cell] = i
		unlockCell(cell, cfg)
	end
	for i,cfg in pairs(passiveSkills) do
		local idx = 0
		local cell = self.gvPassiveBag:GetItem(i - 1)
		cells[cell] = i
		unlockCell(cell, cfg)
	end
end

return M
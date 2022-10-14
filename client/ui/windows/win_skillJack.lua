
local equipSkill
local jack
local cells = {}

local function createSkillCell()
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "Cell")
    cell:SetArea({0, 0}, {0, 0}, {0, 98}, {0, 98})
    local bg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Image")
    bg:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
    bg:SetImage("set:skill_des.json image:add.png")
    cell:AddChildWindow(bg)
    local box = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "SkillImage")
    box:SetArea({0, 0}, {0, 0}, {1, -10}, {1, -10})
    box:SetHorizontalAlignment(1)
    box:SetVerticalAlignment(1)
    cell:AddChildWindow(box)
    return cell
end

local function updateGrid()
    local studySkillMap = Me:data("skill").studySkillMap or {}
    local skillMap = studySkillMap.studySkills or {}
    local equipSkills = studySkillMap.equipSkills or {}
    local oldJack
    for i, skillName in pairs(equipSkills) do
        if skillName == equipSkill.fullName and jack then
            oldJack = i
            break
        end
    end
    local replaceSkillName = equipSkills[jack]
    for i, cell in ipairs(cells) do
        local fullName = equipSkills[i]
        local skill = skillMap[fullName]
        local img = cell:child("SkillImage")
        if i == oldJack then
            if replaceSkillName then
                img:SetImage(Skill.Cfg(replaceSkillName):getIcon())
            else
                img:SetImage("")
            end
        elseif i == jack then
            img:SetImage(Skill.Cfg(equipSkill.fullName):getIcon())
        elseif skill then
            img:SetImage(Skill.Cfg(fullName):getIcon())
        else
            img:SetImage("")
        end
    end
end

local function initGrid(self)
    local equipSkillBarNum = 0
    local skillJack = World.cfg.skillJack or {}
    for _, jackInfo in ipairs(skillJack.sectorSkills or {}) do
        equipSkillBarNum = equipSkillBarNum + jackInfo.jackNum
    end
    self.grid:InitConfig(20, 20, equipSkillBarNum)
    for i = 1, equipSkillBarNum do
        local cell = createSkillCell(self,i)
		cell:SetName("Cell-"..i)
        self.grid:AddItem(cell)
        table.insert(cells, cell)
        self:subscribe(cell, UIEvent.EventWindowClick, function()
            jack = i
            updateGrid()
        end)
    end
end

function M:init()
    WinBase.init(self, "SkillJack.json", true)
    self.title = self:child("SkillJack-Title")
    self.title:SetText(Lang:toText("skillJack.title"))
    self.grid = self:child("SkillJack-Grid")
    self.grid:SetMoveAble(false)
    self.btn = self:child("SkillJack-Btn")
    self.btnTitle = self:child("SkillJack-Btn-Title")
    self.btnTitle:SetText(Lang:toText("skillJack.btn.title"))

    self:subscribe(self.btn, UIEvent.EventButtonClick, function()
        if jack then
            Me:equipSkill(jack, equipSkill)
            jack = nil
        end
        UI:closeWnd("skillJack")
    end)

    initGrid(self)
end

function M:onOpen(skill)
    equipSkill = skill
    updateGrid()
end

return M
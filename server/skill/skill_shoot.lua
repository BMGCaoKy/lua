local SkillBase = Skill.GetType("Base")
local Shoot = Skill.GetType("Shoot")

function Shoot:cast(packet, from)
    if self.skillName then
         Skill.Cast(self.skillName, packet, from)
    end
    SkillBase.cast(self, packet, from)
end
---
---为了减少全局变量的使用，将专一功能的类用service进行管理
---通过使用GetService获取功能进行使用
---

local service = L("service", {})
service["GameReport"] = require "common.service.game_report"

---获取对应服务
---@param name string 服务名称
function Game.GetService(name)
    assert(type(name) == "string", "Must be of string type!")
    return assert(service[name], "No such service :" .. name)
end

RETURN(service)
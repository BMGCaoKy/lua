--- singleton.lua
--- 单例类
---
---@class singleton : middleclass
---@field instance fun(self : singleton, ... : any) : self
---@field clear_instance fun(self : singleton)
local singleton = {
    static = {}
}

---@private
function singleton:included(class)
    -- Override new to throw an error, but store a reference to the old "new" method
    class.static._new = class.static.new
    class.static.new = function()
        error("Use " .. class.name .. ":instance() instead of :new()")
    end
end

function singleton.static:instance(...)
    self._instance = self._instance or self._new(self, ...) -- use old "new" method
    return self._instance
end

function singleton.static:clear_instance()
    self._instance = nil
end

return singleton
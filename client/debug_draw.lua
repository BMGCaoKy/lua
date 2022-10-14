DebugDraw.instance = DebugDraw.Instance()
DebugDraw.luaRenderEntries = DebugDraw.luaRenderEntries or {}
local luaRenderEntries = DebugDraw.luaRenderEntries

function DebugDraw.addEntry(flagName, renderFunc)
    local adjustedName = flagName:sub(1, 1):upper() .. flagName:sub(2) .. 'Enabled'
    local entry = {
        enabled = false,
        render = renderFunc
    }
    luaRenderEntries[flagName] = entry
    DebugDraw['set' .. adjustedName] = function(self, value)
        entry.enabled = value
    end
    DebugDraw['is' .. adjustedName] = function(self)
        return entry.enabled
    end
end

-- used by C++
function debug_draw_lua_render()
    for _, entry in pairs(luaRenderEntries) do
        if entry.enabled then
            entry.render()
        end
    end
end
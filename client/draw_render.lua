DrawRender.instance = DrawRender.Instance()
DrawRender.luaRenderEntries = DrawRender.luaRenderEntries or {}
local luaRenderEntries = DrawRender.luaRenderEntries

function DrawRender.addEntry(flagName, renderFunc)
    local adjustedName = flagName:sub(1, 1):upper() .. flagName:sub(2) .. 'Enabled'
    local entry = {
        enabled = false,
        render = renderFunc
    }
    luaRenderEntries[flagName] = entry
    DrawRender['set' .. adjustedName] = function(self, value)
        entry.enabled = value
    end
    DrawRender['is' .. adjustedName] = function(self)
        return entry.enabled
    end
end

-- used by C++
function draw_lua_render()
    for _, entry in pairs(luaRenderEntries) do
        if entry.enabled then
            entry.render()
        end
    end
end
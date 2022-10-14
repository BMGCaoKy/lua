GridRender.instance = GridRender.Instance()
GridRender.luaRenderEntries = GridRender.luaRenderEntries or {}
local luaRenderEntries = GridRender.luaRenderEntries

function GridRender.addEntry(flagName, renderFunc)
    local adjustedName = flagName:sub(1, 1):upper() .. flagName:sub(2) .. 'Enabled'
    local entry = {
        enabled = false,
        render = renderFunc
    }
    luaRenderEntries[flagName] = entry
    GridRender['set' .. adjustedName] = function(self, value)
        entry.enabled = value
    end
    GridRender['is' .. adjustedName] = function(self)
        return entry.enabled
    end
end

-- used by C++
function grid_lua_render()
    for _, entry in pairs(luaRenderEntries) do
        if entry.enabled then
            entry.render()
        end
    end
end
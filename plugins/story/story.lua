
require "common.story_define"
require "common.story_event"
require "common.config.npc_dialogue_content_config"
require "common.config.npc_dialogue_list_config"

require "client.components.story_command"
require "client.components.story_block"
require "client.components.story_flowchart"
require "client.components.story_writer"

require "client.commands.play_sound"
require "client.commands.shake_camera"
require "client.commands.watch_target"
require "client.commands.say"
require "client.commands.option"
require "client.commands.reset_camera"
require "client.commands.disable_control"
require "client.commands.click_continue"

local handlers = {}

function handlers.onGameReady()
    if World.isClient then
        UI:getWnd("sayDialog")
    end
end

function handlers.onPlayerReady(player)
    Lib.logInfo("plugin onPlayerReady")

end

function handlers.onPlayerLogout(player)

end

return function(name, ...)
    if type(handlers[name]) ~= "function" then
        return
    end
    handlers[name](...)
end
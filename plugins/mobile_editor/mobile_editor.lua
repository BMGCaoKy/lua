--- mobile_editor.lua

if World.isClient and Blockman.Instance().singleGame and CGame.instance:getIsMobileEditor() and CGame.instance:getIsEditor() then
    require "report_mobile_editor"
    require "common.util.imageset_util"
    require "common.util.sound_util"
    require "common.manager.manager_init"
    require "common.gm.gm_client"
    require "mobile_editor_define"
    require "mobile_editor_event_define"
    require "client.player.mobile_editor_player_packet"
    require "client.world.mobile_editor_map"
    require "client.world.mobile_editor_map_event"
    require "client.mobile_editor_entry"
else

end
local Lfs = require "lfs"

require "client/editor_player_packet"
require "client/editor_event"
require "client/editor_client"
require "client/editor_break_block"
require "client/editor_place_block"
require "client/editor_entity"
require "client/editor_ui_lib"
require "client/editor_ui_schedule"
require "client/editor_dropitem"
require "client/editor_lib"
require "client/editor_commodity"
require "client/editor_click"
require "client/editor_skill.editor_use_item"
require "client/editor_skill.editor_melee_attack"
require "client/editor_skill.editor_bucket_skill"
require "client/editor_cellPool"
require "client/editor_item_class"

Lib.subscribeEvent(Event.EVENT_FINISH_DEAL_GAME_INFO, function()
    Blockman.instance.gameSettings:setUiActorBrightness({x = 0.8, y = 0.8, z = 0.8})
end)


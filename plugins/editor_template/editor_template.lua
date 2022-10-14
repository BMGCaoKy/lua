print("start load editor game template pulgin!")
require "common/editor_item_class"
require "common/editor_missile"
require "common/editor_entity"
if not World.isClient then
    require "server/editor_main"
else
    require "client/editor_main"
end

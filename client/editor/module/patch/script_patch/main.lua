if not World.isClient then
    require "script_server.main"
else
    require "script_client.main"
end
require "item_class"
require "missile"
require "entity"
require "version"

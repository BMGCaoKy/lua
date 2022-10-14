local ModuleBase = require "editor.gamedata.module.class.module_base"

local M = Lib.derive(ModuleBase)

local MODULE_NAME = "map"
local ITEM_TYPE = "MapCfg"

function M:init(name)
	assert(name == MODULE_NAME, 
		string.format("[ERROR] module name not match %s:%s", MODULE_NAME, name)
	)

	ModuleBase.init(self, MODULE_NAME, ITEM_TYPE)
end

function M:on_new_item(id)
	-- ��ͼģ����Ҫ�ȴ浥 ����Ϊ�ж�Ӧ�� mca �ļ���Ҫ�浽�ļ���
	local item = self:item(id)
	item:save()

	ModuleBase.on_new_item(self, id)
end

return M

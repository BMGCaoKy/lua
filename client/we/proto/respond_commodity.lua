local Commodity = require "we.logic.commodity.commodity"

return {
	COMMODITY_ADD_PAGE = function(index)
		Commodity:add_page(index)
		return {ok = true}
	end,

	COMMODITY_COPY_PAGE = function(index)
		Commodity:copy_page(index)
		return {ok = true}
	end,

	COMMODITY_COPY_ITEM = function(pageIndex, commodityIndex)
		Commodity:copy_commodity(pageIndex, commodityIndex)
		return {ok = true}
	end
}

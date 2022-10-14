local Receptor = require "we.view.scene.receptor.receptor"
local Camera = require "we.view.scene.camera"

return {
	FOCUS = function()
		local receptor = Receptor:binding()
		if not receptor then
			return
		end

		local bound = receptor:bound()
		if not bound then
			return
		end
		Camera:focus(bound)
	end
}
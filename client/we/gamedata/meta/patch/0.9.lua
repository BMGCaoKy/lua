local meta = {
	{
		type = "Action_BinaryOper",
		value = function(oval)
			local ret = Lib.copy(oval)

			local component_sequence = ret.components[2]
			if not component_sequence then
				-- 内测版本可能0.8已经用了最新的meta
				return ret
			end

			ret.components[2] = nil

			local a1 = component_sequence.children[1] and component_sequence.children[1].action
			local a2 = component_sequence.children[2] and component_sequence.children[2].action

--			ret.components[1].params[2] = {key = "left", value = {__OBJ_TYPE = "T_Bool", action = a1}, must = true}
--			ret.components[1].params[3] = {key = "right", value = {__OBJ_TYPE = "T_Bool", action = a2}, must = true}
			ret.components[1].params[2] = {key = "left", value = ctor("T_Bool", {action = a1}), must = true}
			ret.components[1].params[3] = {key = "right", value = ctor("T_Bool", {action = a2}), must = true}

			return ret
		end
	},

	{
		type = "Trigger",
		value = function(oval)
			local ret = Lib.copy(oval)

			local min_x, min_y = ret.root.pos.x, ret.root.pos.y
			
			local function update_border(actions)
				for _, action in ipairs(actions) do
					if action.pos.x < min_x then
						min_x = action.pos.x
					end

					if action.pos.y < min_y then
						min_y = action.pos.y
					end

					if action.__OBJ_TYPE == "Node_CollapseGraph" then
						update_border(action.actions)
					end
				end
			end

			update_border(ret.actions)

			local function update_action_pos(actions)
				for _, action in ipairs(actions) do
					action.pos.x = action.pos.x - min_x
					action.pos.y = action.pos.y - min_y

					if action.__OBJ_TYPE == "Node_CollapseGraph" then
						update_action_pos(action.actions)
					end
				end
			end

			ret.root.pos.x, ret.root.pos.y = ret.root.pos.x - min_x, ret.root.pos.y - min_y
			update_action_pos(ret.actions)

			return ret
		end
	}
}

return {
	meta = meta
}

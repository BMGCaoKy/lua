

function SceneLib.showOrHideAllConstraint(isShow)
	isShow = not not isShow
	local manager = World.CurWorld:getSceneManager()
	local scenes = manager:getAllScene()
	local function isConstraintClass(class)
		return class == "FixedConstraintClient" or class == "HingeConstraintClient" or class == "RodConstraintClient" or class == "RopeConstraintClient" or 
			class == "SliderConstraintClient" or class == "SpringConstraintClient"
	end
	for _, scene in ipairs(scenes) do 
		for _, curPart in pairs(scene:getRoot():getDescendants()) do
			if not curPart:isValid() then
				goto continue
			end
			if not isConstraintClass(curPart:getTypeName()) then
				goto continue
			end
			curPart:setDebugGraphShow(isShow)
			::continue::
		end
	end
end
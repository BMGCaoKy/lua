local msin = math.sin
local mcos = math.cos
local mrad = math.rad
local loadstring = rawget(_G, "loadstring") or load

function UILib.updateMask(cells, startTime, updateTime, stopTime)
    local mask = 0
	local upMask = 1 / ((stopTime - startTime) / 2)
	local temp = (updateTime or 0) - startTime
	if temp > 0 then
		mask = temp / 2 * upMask
	end
	local function updateCellsMask(mask)
		for _, cell in ipairs(cells) do
			if cell then
				cell:setMask(mask)
			end
		end
	end
	updateCellsMask(1 - mask)
    local function tick()
        mask = mask + upMask
        if mask >= 1 then
            updateCellsMask(0)
            return false
        end
        updateCellsMask(1 - mask)
        return true
    end
    return World.Timer(2, tick)
end

function UILib.uiTween(ui, PropertyObj, time, finishBackF)
	local getPropertyToList = function()
		local result = {}
		for key, value in pairs(PropertyObj) do
			local targetValue = {}
			if type(value) == "table" then
				for _, v in pairs(value) do
					targetValue[#targetValue + 1] = v
				end
				targetValue = "{" .. table.concat( targetValue, ",") .. "}"
			else
				targetValue = tostring(value)
			end

			result[#result + 1] = {
				name = tostring(key),
				targetValue = targetValue
			}
		end
		return result
	end
	local propertyList = getPropertyToList()
	Blockman.instance:uiTweenTo(ui,propertyList, time)
	return World.Timer(time, function()
		if finishBackF then
			finishBackF()
		end
	end)
end

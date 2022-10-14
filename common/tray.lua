function Tray:new_tray(type, capacity, system)
	local class_name = assert(Define.TRAY_TYPE_CLASS[type], tostring(type))

	local class = require(string.format("%s.tray_class_%s", "tray.class", class_name))
	assert(class, string.format("class %s is not exist", class_name))

	local obj = Lib.derive(class)
	obj:init(type, capacity, system)

	return obj
end

function Tray:seri_tray(tray, save)
	return {
		type = tray:type(),
		capacity = tray:capacity(),
		maxCapacity = tray:max_capacity()
	}, tray:seri(), tray:seri_item(save), tray:system()
end

function Tray:seri_tray_items(tray, save)
	return tray:seri_item(save)
end

function Tray:deseri_tray(data)
	local obj = self:new_tray(data.type, data.capacity)
	obj:deseri(data.rawdata)
	return obj
end

function Tray:deseri_tray_system(type, capacity, data)
	local obj = self:new_tray(type, capacity, true)
	obj:deseri(data and data.rawdata)
	return obj
end

function Tray:check_switch(tray_1, slot_1, tray_2, slot_2)
	assert(tray_1 and slot_1 and tray_2 and slot_2)
	if tray_1 == tray_2 and slot_1 == slot_2 then
		return true
	end

	local item_1 = tray_1:fetch_item(slot_1)
	local item_2 = tray_2:fetch_item(slot_2)

    local ret, key = tray_1:check_pick(slot_1)
	if not ret then
		return false, key
	end

    local ret, key = tray_1:check_drop(item_2)
	if not ret then
		return false, key
	end

    local ret, key = tray_2:check_pick(slot_2)
	if not ret then
		return false, key
	end

    local ret, key = tray_2:check_drop(item_1) 
	if not ret then
		return false, key
	end

	return true
end

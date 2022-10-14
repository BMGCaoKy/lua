
function DropItemClient:updateARGBStrength()
	if self:data("item"):var("attachVar") and self:data("item"):var("attachVar").isAttach then 
		self:setARGBStrength(228/255, 119/255, 255/255, 1)
	else
		self:setARGBStrength(1,1,1,1)
	end
end

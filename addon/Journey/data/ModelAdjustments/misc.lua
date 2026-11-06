function DataminePlayerModelMixin:GetScaledActiveBoundingBox()
	local scale = self:GetScale();
	local x1, y1, z1, x2, y2, z2 = self:GetScaledActiveBoundingBox();
	if x1 ~= nil then
		return x1 * scale, y1 * scale, z1 * scale, x2 * scale, y2 * scale, z2 * scale;
	end
end

function DataminePlayerModelMixin:OnModelLoaded()
	local scene = self:GetParent();
	local minX = math.huge;
	local minY = math.huge;
	local minZ = math.huge;
	local maxX = -math.huge;
	local maxY = -math.huge;
	local maxZ = -math.huge;
	for i=1, scene:GetNumActors() do
		local actor = scene:GetActorAtIndex(i);
		local x, y, z = actor:GetScaledPosition();
		local x1, y1, z1, x2, y2, z2 = actor:GetScaledActiveBoundingBox();
		if x1 ~= nil then
			minX = math.min(minX, x + x1);
			minY = math.min(minY, y + y1);
			minZ = math.min(minZ, z + z1);
			maxX = math.min(maxX, x + x2);
			maxY = math.min(maxY, y + y2);
			maxZ = math.min(maxZ, z + z2);
		end
	end
	local lx = maxX - minX;
	local ly = maxY - minY;
	local lz = maxZ - minZ;
	local size = math.sqrt(lx ^ 2 + ly ^ 2 + lz ^ 2) * 1.5;
	local angle = math.max(lx, ly) < lz and 0 or 45 / 2;
	local camera = scene:GetActiveCamera();
	camera:SetPitch(math.rad(angle));
	camera:SetTarget(minX + lx / 2, minY + ly / 2, minZ + lz / 2);
	camera:SetMinZoomDistance(size);
	camera:SetMaxZoomDistance(size);
	camera:SetZoomDistance(size);
	camera:SnapAllInterpolatedValues();
end
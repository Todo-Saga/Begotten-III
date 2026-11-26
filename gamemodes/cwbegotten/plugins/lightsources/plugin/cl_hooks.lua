--[[
	Begotten III: Jesus Wept
--]]

-- Called when the local player's item functions should be adjusted.
function cwLantern:PlayerAdjustItemFunctions(itemTable, itemFunctions)
	--[[
	if (itemTable.lantern) then
		if (itemTable:GetData("IsWorn", false) == true) then
			itemFunctions[#itemFunctions + 1] = {
				title = "Remove From Hip",
				name = "wearlantern"
			};
		elseif (itemTable:GetData("IsWorn") == false) then
			itemFunctions[#itemFunctions + 1] = {
				title = "Wear On Hip",
				name = "unwearlantern"
			};
		end;
	end;
	--]]
end;

local function sortByDist(a, b)
	return a.distSq < b.distSq;
end;

local vecDown20 = Vector(0, 0, 20);
local vecDown15 = Vector(0, 0, 15);

-- Called every frame.
function cwLantern:Think()
	local curTime = CurTime();
	
	if (!self.lanternPlayers) then
		self.lanternPlayers = {};
	end;
	
	if (!self.nextLanternPlayers or self.nextLanternPlayers < curTime) then
		self.nextLanternPlayers = curTime + 1;
		self.lanternPlayers = {};
		
		local clientPosition = Clockwork.Client:GetPos();
		local reqDistance = (2000 * 2000);
		
		if (zones and zones.currentFogEnd) then
			reqDistance = (zones.currentFogEnd * zones.currentFogEnd);
		end;

		local candidates = {};

		for _, v in _player.Iterator() do
			if (v:Alive() and not v:IsDormant() and not v:GetNetVar("hidden")) then
				local isRaised, activeWeapon = v:IsWeaponRaised();
				local hasLantern = v:GetNetVar("lanternOnHip");
				if not hasLantern and isRaised then
					if IsValid(activeWeapon) and activeWeapon:GetClass() == "cw_lantern" then
						hasLantern = true;
					end;
				end;
				
				if hasLantern and (v:GetNetVar("oil", 0) > 0) then
					local position = v:GetPos();
					local distSq = position:DistToSqr(clientPosition);
					
					if (distSq <= reqDistance) then
						if (v == Clockwork.Client) then
							self.lanternPlayers[v] = true;
						else
							candidates[#candidates + 1] = {ply = v, distSq = distSq};
						end;
					end;
				end;
			end;
		end;

		if (#candidates > 24) then
			table.sort(candidates, sortByDist);
			for i = 1, 24 do
				self.lanternPlayers[candidates[i].ply] = true;
			end;
		else
			for i = 1, #candidates do
				self.lanternPlayers[candidates[i].ply] = true;
			end;
		end;
	end;
	
	for k, v in pairs (self.lanternPlayers) do
		if !IsValid(k) or !k:Alive() then
			self.lanternPlayers[k] = nil;
			continue;
		end;
		if k:IsDormant() then
			continue;
		end;
		
		local isRaised, activeWeapon = k:IsWeaponRaised();
		
		if !k:GetNetVar("lanternOnHip") and (!isRaised or not IsValid(activeWeapon) or activeWeapon:GetClass() != "cw_lantern") then
			self.lanternPlayers[k] = nil;
			continue;
		end;
		
		if k:GetNetVar("hidden") then
			self.lanternPlayers[k] = nil;
			continue;
		end;
		
		local currentOil = k:GetNetVar("oil", 0);
		local handIndex = k:GetNetVar("lanternOnHip", false) and k:LookupBone("ValveBiped.Bip01_R_Thigh") or k:LookupBone("ValveBiped.Bip01_R_Hand");

		if (!handIndex) then 
			continue;
		end;

		local originalSize = 666;

		if (currentOil < 25) then
			if currentOil <= 0 then
				continue;
			end
		
			originalSize = Lerp(currentOil, originalSize / 2, originalSize);
		end;
		
		local entIndex = k:EntIndex();
		local dynamicLight = DynamicLight(entIndex);
		local lightPos;

		if k == Clockwork.Client and !k:ShouldDrawLocalPlayer() and !k:GetNetVar("lanternOnHip", false) then
			local eyePos = k:EyePos();
			local eyeAng = k:EyeAngles();
			lightPos = eyePos + eyeAng:Forward() * 8 + eyeAng:Right() * 8 - eyeAng:Up() * 10;
		else
			local bonePos = handIndex and k:GetBonePosition(handIndex);
			if bonePos and not bonePos:IsZero() and bonePos ~= k:GetPos() then
				lightPos = bonePos - vecDown20;
			else
				lightPos = k:EyePos() + k:GetForward() * 15 - vecDown15;
			end
		end
		
		if (dynamicLight and lightPos) then
			dynamicLight.Pos = lightPos; 
			dynamicLight.r = 255;
			dynamicLight.g = 200;
			dynamicLight.b = 115;
			dynamicLight.Brightness = 1;
			dynamicLight.Size = originalSize;
			dynamicLight.DieTime = curTime + 0.1;
			dynamicLight.Style = 6;
		end;
	end;
end;

-- Called when the bars are needed.
function cwLantern:GetBars(bars)
	local activeWeapon = Clockwork.Client:GetActiveWeapon();
	
	if (activeWeapon:IsValid()) then
		local activeClass = activeWeapon:GetClass();
		
		if (activeClass == "cw_lantern" or Clockwork.Client:GetNetVar("lanternOnHip", false)) then
			local oil = Clockwork.Client:GetNetVar("oil", 0);
			
			--if (oil < 50) then
				local oilColor = oil / 100;
				local color = Color(255 * oilColor, 200 * oilColor, 50 * oilColor);
				local oilText = self:GetOilText();
				
				if (oil) then
					if (!self.oil) then
						self.oil = oil;
					else
						self.oil = math.Approach(self.oil, oil, 1);
					end;
					
					bars:Add("OIL", color, oilText, self.oil, 100, self.oil < 10);
				end;
			--end;
		end;
	end;
end;

function cwLantern:SubModifyItemMarkupTooltip(category, maximumWeight, weight, condition, percentage, name, itemTable, x, y, width, height, frame, bShowWeight)
	if category == "Lights" then
		local oil = itemTable:GetData("oil", 0);
		local percentage = math.min(oil / 100, 100);
		local oilColor = oil / 100;
		local color = Color(255 * oilColor, 200 * oilColor, 50 * oilColor);
		local oilText = self:GetOilText(oil);
		
		frame:AddBar(20, {{text = oilText, percentage = percentage * 100, color = color, font = "DermaDefault", leftTextAlign = false, noDisplay = true}}, "Fuel Remaining: ", Color(170, 170, 180));
	end
end

--[[
	Begotten III: Jesus Wept
	By: DETrooper, cash wednesday, gabs, alyousha35

	Other credits: kurozael, Alex Grist, Mr. Meow, zigbomb
--]]

local entityMeta = FindMetaTable("Entity");

function cwZombies:IsZombieNPC(entity)
	if not IsValid(entity) then return false end;
	local npcCount = self.zombieNPCS and #self.zombieNPCS or 0;
	if (not self.zombieNPCSet or self._zombieNPCSCount ~= npcCount) and self.zombieNPCS then
		self.zombieNPCSet = {};
		self._zombieNPCSCount = npcCount;
		for _, class in pairs(self.zombieNPCS) do
			self.zombieNPCSet[class] = true;
		end;
	end;
	local class = entity:GetClass();
	if (self.zombieNPCSet and self.zombieNPCSet[class]) or entity.IsZombie == true then
		return true;
	end;
	if isfunction(entity.IsZombie) and (not entityMeta or entity.IsZombie ~= entityMeta.IsZombie) then
		return entity:IsZombie() == true;
	end;
	return false;
end;

--[[cwZombies.manualZombieSpawns = cwZombies.manualZombieSpawns or {};

-- A function to make a zombie spring up from the dead.
function cwZombies:UndeadScare(entity, player)
	if (!player or !IsValid(player)) then
		player = table.Random(PlayerCache or _player.GetAll());
	end;
	
	timer.Simple(0.5, function()
		if (IsValid(player) and IsValid(entity)) then
			local headIndex = entity:LookupBone("ValveBiped.Bip01_Head1");
			local physCount = entity:GetPhysicsObjectCount();
			
			for i = 1, physCount do
				local physicsObject = entity:GetPhysicsObjectNum(i);
				local boneIndex = entity:TranslatePhysBoneToBone(i);
				
				if (IsValid(physicsObject)) then
					if (boneIndex == headIndex) then
						physicsObject:ApplyForceCenter(Vector(0, 0, 10000));
					end
				end;
			end;
			
			local zombieNPC = ents.Create("cw_zombie");
				zombieNPC:SetPos(entity:GetPos() + entity:GetPos():GetNormal() * 20);
				zombieNPC:SetAngles(Angle(0, 0, 0));
			zombieNPC:Spawn();
			
			zombieNPC:SetEnemy(player);
			
			timer.Simple(FrameTime(), function()
				if (IsValid(zombieNPC) and IsValid(entity)) then
					zombieNPC:SetModel(entity:GetModel());
					zombieNPC:SetSkin(entity:GetSkin());
					
					entity:Remove();
				end;
			end);
		end;
	end);
end;

-- A function to drop a grenade at a zombie's position.
function cwZombies:ZombieGrenade(entity)
	local grenade = ents.Create("prop_physics");
		grenade:SetPos(entity:GetPos() + Vector(0, 0, 16));
		grenade:SetAngles(Angle(0, 0, 90));
		grenade:SetModel("models/weapons/w_grenade.mdl");
	grenade:Spawn();
	
	local pitch = 100;

	timer.Create(grenade:EntIndex().."_tick", 0.5, 6, function()
		grenade:EmitSound("weapons/grenade/tick1.wav", 80, pitch);
		
		pitch = pitch + 5;
	end);
	
	timer.Simple(3.5, function()
		if (IsValid(grenade)) then
			grenade:Remove();
			
			local effectData = EffectData();
				effectData:SetStart(grenade:GetPos());
				effectData:SetOrigin(grenade:GetPos());
				effectData:SetScale(scale or 8);
			util.Effect("Explosion", effectData);

			for k, v in ipairs(ents.FindInSphere(grenade:GetPos(), 196)) do
				local damageInfo = DamageInfo();
					damageInfo:SetDamageType(DMG_BLAST);
					damageInfo:SetDamage(math.random(70, 130));
					damageInfo:SetAttacker(grenade);
					damageInfo:SetInflictor(grenade);
					damageInfo:SetDamageForce(Vector(100, 100, 100));
				v:TakeDamageInfo(damageInfo);
			end;
		end;
	end);
end;

-- A function to spawn a zombie NPC at a given position.
function cwZombies:SpawnZombie(class, position)
	local zombie = ents.Create(class);
	
	if (IsValid(zombie)) then
		zombie:SetPos(position + position:GetNormalized() * 20);
		zombie:SetAngles(Angle(0, 0, 0));
		
		if (math.random(1, 3) == 3) then
			zombie:SetEnemy(table.Random(PlayerCache or _player.GetAll()));
		end;
		
		for _, v in _player.Iterator() do
			local playerPosition = v:GetPos();
			local zombiePosition = zombie:GetPos();
			local distance = zombiePosition:Distance(playerPosition);
			local randomSound = nil;
			
			if (distance > 0 and distance <= 1000) then
				randomSound = "begotten/l4d2/mob/germx"..math.random(1, 2)..table.Random({"a", "b"})..".wav";
			elseif (distance > 1000 and distance <= 2000) then
				randomSound = "begotten/l4d2/mob/germl"..math.random(1, 2)..table.Random({"a", "b"})..".wav";
			elseif (distance > 2000 and distance <= 3000) then
				randomSound = "begotten/l4d2/mob/germm"..math.random(1, 2)..table.Random({"a", "b"})..".wav";
			elseif (distance > 3000 and distance <= 4000) then
				randomSound = "begotten/l4d2/mob/germs"..math.random(1, 2)..table.Random({"a", "b"})..".wav";
			else
				randomSound = table.Random({
					"begotten/l4d2/glimpse_death1.mp3",
					"begotten/l4d2/glimpse_death2.mp3",
					"begotten/l4d2/glimpse_hell1.mp3",
					"begotten/l4d2/glimpse_hell2.mp3",
					"begotten/l4d2/glimpse_hell3.mp3"
				})
				
				if (math.random(1, 10) == 10) then
					randomSound = "begotten/l4d2/mob/walkingdead.wav";
				end;
			end;
			
			if (randomSound) then
				netstream.Start(v, "PlaySound", randomSound);
			end;
		end;
	end;
end;]]--

function cwZombies:GiveAwayPosition(entity, radius)
	if not IsValid(entity) then return end;
	local playerPosition = entity:GetPos();
	local maxDistSq = (radius or 2500) ^ 2;
	
	if self.activeZombies then
		for v in pairs(self.activeZombies) do
			if IsValid(v) then
				if v:Health() > 0 and not (v.IsDead and v:IsDead()) and v:GetPos():DistToSqr(playerPosition) <= maxDistSq then
					v:SetEnemy(entity);
					break;
				end
			else
				self.activeZombies[v] = nil;
			end
		end
		return;
	end

	for _, v in ipairs(ents.FindInSphere(playerPosition, radius or 2500)) do
		if (v:IsNPC() or v:IsNextBot()) and v:Health() > 0 and not (v.IsDead and v:IsDead()) and self:IsZombieNPC(v) then
			v:SetEnemy(entity);
			break;
		end;
	end;
end

-- A function to spawn a Begotten thrall.
function cwZombies:SpawnThrall(name, spawnPos, angles)
	local entity;
	
	if name == "npc_bgt_another" or string.lower(name) == "another" then
		entity = ents.Create("npc_bgt_another");
	elseif name == "npc_bgt_brute" or string.lower(name) == "brute" then
		entity = ents.Create("npc_bgt_brute");
	elseif name == "npc_bgt_chaser" or string.lower(name) == "chaser" then
		entity = ents.Create("npc_bgt_chaser");
	elseif name == "npc_bgt_coinsucker" or string.lower(name) == "coinsucker" then
		entity = ents.Create("npc_bgt_coinsucker");
	elseif name == "npc_bgt_eddie" or string.lower(name) == "eddie" then
		entity = ents.Create("npc_bgt_eddie");
	elseif name == "npc_bgt_grunt" or string.lower(name) == "grunt" then
		entity = ents.Create("npc_bgt_grunt");
	elseif name == "npc_bgt_guardian" or string.lower(name) == "guardian" then
		entity = ents.Create("npc_bgt_guardian");
	elseif name == "npc_bgt_ironclad" or string.lower(name) == "ironclad" then
		entity = ents.Create("npc_bgt_ironclad");
	elseif name == "npc_bgt_otis" or string.lower(name) == "otis" then
		entity = ents.Create("npc_bgt_otis");
	elseif name == "npc_bgt_pursuer" or string.lower(name) == "pursuer" then
		entity = ents.Create("npc_bgt_pursuer");
	elseif name == "npc_bgt_shambler" or string.lower(name) == "shambler" then
		entity = ents.Create("npc_bgt_shambler");
	elseif name == "npc_bgt_suitor" or string.lower(name) == "suitor" then
		entity = ents.Create("npc_bgt_suitor");
	end
	
	if IsValid(entity) then
		local trace = util.TraceHull({
			start = spawnPos + Vector(0, 0, 12),
			endpos = spawnPos - Vector(0, 0, 64),
			mins = Vector(-18, -18, 0),
			maxs = Vector(18, 18, 72),
			filter = entity,
			mask = MASK_NPCSOLID,
		});
		if trace.Hit and not trace.StartSolid and util.IsInWorld(trace.HitPos + Vector(0, 0, 4)) then
			spawnPos = trace.HitPos + Vector(0, 0, 4);
		elseif !util.IsInWorld(spawnPos) then
			local raised = spawnPos + Vector(0, 0, 16);
			if util.IsInWorld(raised) then
				spawnPos = raised;
			end;
		end

		local spawnAng = angles and Angle(0, angles.y, 0) or angle_zero;
		entity:CustomInitialize();
		entity:SetPos(spawnPos);
		entity:SetAngles(spawnAng);
		entity:Spawn();
		entity:Activate();
		if entity.loco then
			entity.loco:SetVelocity(vector_origin);
		end;

		if self:IsZombieNPC(entity) then
			if not self.activeZombies then self.activeZombies = {}; end;
			self.activeZombies[entity] = true;
		end;

		local phys = entity:GetPhysicsObject();
		if IsValid(phys) then
			phys:SetVelocity(Vector(0, 0, 0));
			phys:SetAngleVelocity(Vector(0, 0, 0));
		end;
	end
		
	return entity;
end
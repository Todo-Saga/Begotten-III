--[[
	Begotten III: Jesus Wept
	By: DETrooper, cash wednesday, gabs, alyousha35

	Other credits: kurozael, Alex Grist, Mr. Meow, zigbomb
--]]

if (netvars) then return end

library.New("netvars", _G)

local entityMeta = FindMetaTable("Entity")
local playerMeta = FindMetaTable("Player")

local stored = {}
local globals = {}
-- Keys set through SetLocalVar, per player. These are private to that player and must not go out in join snapshots.
local localKeys = setmetatable({}, {__mode = "k"})

util.AddNetworkString("nVar")
util.AddNetworkString("nDel")
util.AddNetworkString("nLcl")
util.AddNetworkString("gVar")
util.AddNetworkString("cwVarsSync")

-- Check if there is an attempt to send a function. Can't send those.
local function checkBadType(name, object)
	local objectType = type(object)

	if (objectType == "function") then
		ErrorNoHalt("Net var '"..name.."' contains a bad object type!\n")

		return true
	elseif (objectType == "table") then
		for k, v in pairs(object) do
			-- Check both the key and the value for tables, and has recursion.
			if (checkBadType(name, k) or checkBadType(name, v)) then
				return true
			end
		end
	end
end

function netvars.SetNetVar(key, value, receiver)
	if (checkBadType(key, value)) then return end
	if (netvars.GetNetVar(key) == value) then return end
	if (globals[key] == value) then return end

	globals[key] = value
	--netstream.Start(receiver, "gVar", key, value)
	net.Start("gVar")
		net.WriteString(key)
		net.WriteType(value)
		
	if receiver then
		net.Send(receiver)
		return;
	end
	
	net.Broadcast()
end

function netvars.AreEqual(old, new)
	if (istable(old) and istable(new)) then
		return Clockwork.kernel:AreTablesEqual(old, new), "table"
	elseif (old == new) then
		return true
	end

	return false
end

function playerMeta:SyncVars()
	if (not IsValid(self) or self:IsBot()) then return end

	local syncTable = {}

	for entity, data in pairs(stored) do
		if (not IsValid(entity)) then
			stored[entity] = nil
			localKeys[entity] = nil
		elseif (next(data) ~= nil) then
			local private = (entity ~= self) and localKeys[entity]

			if (private and next(private) ~= nil) then
				local public = {}

				for k, v in pairs(data) do
					if (not private[k]) then
						public[k] = v
					end
				end

				if (next(public) ~= nil) then
					syncTable[#syncTable + 1] = {entity:EntIndex(), public}
				end
			else
				syncTable[#syncTable + 1] = {entity:EntIndex(), data}
			end
		end
	end

	--netstream.Start(self, "gVar", k, v)
	-- One snapshot of entity and global vars. pON keeps the array shape; compressed and split under the net message size limit.
	local payload = util.Compress(pon.encode({syncTable, globals}))
	if not payload then return end

	local chunkSize = 60000
	local parts = math.ceil(#payload / chunkSize)

	for i = 1, parts do
		local chunk = string.sub(payload, (i - 1) * chunkSize + 1, i * chunkSize)

		net.Start("cwVarsSync")
			net.WriteUInt(i, 16)
			net.WriteUInt(parts, 16)
			net.WriteUInt(#chunk, 16)
			net.WriteData(chunk, #chunk)
		net.Send(self)
	end
end

local function FilterHumanReceiver(receiver)
	if (receiver == nil) then
		return nil, true
	end

	if (istable(receiver)) then
		local humans = {}
		for i = 1, #receiver do
			local p = receiver[i]
			if (IsValid(p) and (not p:IsPlayer() or not p:IsBot())) then
				humans[#humans + 1] = p
			end
		end
		return humans, (#humans > 0)
	end

	if (IsValid(receiver) and receiver:IsPlayer() and receiver:IsBot()) then
		return nil, false
	end

	return receiver, true
end

function entityMeta:SendNetVar(key, receiver)
	local target, shouldSend = FilterHumanReceiver(receiver)
	if (not shouldSend) then return end

	--netstream.Heavy(receiver, "nVar", self:EntIndex(), key, stored[self] and stored[self][key])
	net.Start("nVar")
		net.WriteUInt(self:EntIndex(), 14);
		net.WriteString(key)
		net.WriteType(stored[self] and stored[self][key])
		
	if target then
		net.Send(target)
		return;
	end
	
	net.Broadcast()
end

function entityMeta:ClearNetVars(receiver)
	localKeys[self] = nil

	if stored[self] then
		stored[self] = nil
		local idx = self:EntIndex()
		if (idx < 0 or idx >= 16384) then return end

		local target, shouldSend = FilterHumanReceiver(receiver)
		if (not shouldSend) then return end

		--netstream.Start(receiver, "nDel", self:EntIndex())
		net.Start("nDel")
			net.WriteUInt(idx, 14)
			
		if target then
			net.Send(target)
			return;
		end
		
		net.Broadcast()
	end
end

function entityMeta:SetNetVar(key, value, receiver)
	if (checkBadType(key, value)) then return end
	-- Compare against the raw stored value: GetNetVar uses `or default`, so a stored false read back as nil and was resent every call.
	if (!istable(value) and stored[self] and stored[self][key] == value) then return end
	if (value == nil and (not stored[self] or stored[self][key] == nil)) then return end

	if (localKeys[self]) then
		localKeys[self][key] = nil
	end

	stored[self] = stored[self] or {}
	stored[self][key] = value

	self:SendNetVar(key, receiver)
end

function entityMeta:SetLocalVar(key, value)
	if !self:IsPlayer() then
		self:SetNetVar(key, value);
	
		return;
	end

	if (checkBadType(key, value)) then return end
	if (!istable(value) and stored[self] and stored[self][key] == value) then return end
	if (value == nil and (not stored[self] or stored[self][key] == nil)) then return end

	localKeys[self] = localKeys[self] or {}
	localKeys[self][key] = true

	stored[self] = stored[self] or {}
	stored[self][key] = value

	if (not self:IsBot()) then
		--netstream.Start(self, "nLcl", key, value)
		net.Start("nLcl")
			net.WriteString(key)
			net.WriteType(value)
		net.Send(self)
	end
end


function entityMeta:GetNetVar(key, default)
	local storedIndex = stored[self];

	if (storedIndex) then
		return storedIndex[key] or default;
	end

	return default
end

playerMeta.GetLocalVar = entityMeta.GetNetVar

function netvars.GetNetVar(key, default)
	local value = globals[key]

	return value != nil and value or default
end

hook.Add("EntityRemoved", "nCleanUp", function(entity)
	entity:ClearNetVars()
end)

hook.Add("PlayerInitialSpawn", "nSync", function(client)
	client:SyncVars()
end)
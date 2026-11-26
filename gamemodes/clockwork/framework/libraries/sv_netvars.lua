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
util.AddNetworkString("nVarB")
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

local function HasHumanPlayers()
	for _, p in _player.Iterator() do
		if (IsValid(p) and not p:IsBot()) then
			return true
		end
	end
	return false
end

local function FallbackSendSnapshot(ply, syncTable, globalsTbl)
	if (not IsValid(ply) or ply:IsBot()) then return end
	-- An empty snapshot after the raw vars tells the client the initial sync is finished, so it stops tracking touched keys.
	local function SendSyncDone()
		local ok, encoded = pcall(pon.encode, {{}, {}})
		local payload = ok and encoded and util.Compress(encoded)
		if (not payload or #payload == 0) then return end
		net.Start("cwVarsSync")
			net.WriteUInt(1, 16)
			net.WriteUInt(1, 16)
			net.WriteUInt(#payload, 16)
			net.WriteData(payload, #payload)
		net.Send(ply)
	end
	for i = 1, #syncTable do
		local entry = syncTable[i]
		local idx, data = entry[1], entry[2]
		if (isnumber(idx) and idx >= 0 and idx <= 16383 and istable(data)) then
			for k, v in pairs(data) do
				net.Start("nVar")
					net.WriteUInt(idx, 14)
					net.WriteString(k)
					net.WriteType(v)
				net.Send(ply)
			end
		end
	end
	for k, v in pairs(globalsTbl) do
		net.Start("gVar")
			net.WriteString(k)
			net.WriteType(v)
		net.Send(ply)
	end
	SendSyncDone()
end

function playerMeta:SyncVars()
	if (not IsValid(self) or self:IsBot()) then return end

	local syncTable = {}

	for entity, data in pairs(stored) do
		if (not IsValid(entity)) then
			stored[entity] = nil
			localKeys[entity] = nil
		elseif (next(data) ~= nil) then
			local idx = entity:EntIndex()
			if (idx < 0 or idx > 16383) then continue end

			local private = (entity ~= self) and localKeys[entity]

			if (private and next(private) ~= nil) then
				local public = {}

				for k, v in pairs(data) do
					if (not private[k]) then
						public[k] = v
					end
				end

				if (next(public) ~= nil) then
					syncTable[#syncTable + 1] = {idx, public}
				end
			else
				syncTable[#syncTable + 1] = {idx, data}
			end
		end
	end

	-- One snapshot of entity and global vars. pON keeps the array shape; compressed and split under the net message size limit.
	local ok, encoded = pcall(pon.encode, {syncTable, globals})
	if (not ok or not encoded) then
		ErrorNoHalt("[Clockwork:NetVars] pon.encode failed in SyncVars: " .. tostring(encoded) .. "\n")
		FallbackSendSnapshot(self, syncTable, globals)
		return
	end
	local payload = util.Compress(encoded)
	if (not payload or #payload == 0) then
		FallbackSendSnapshot(self, syncTable, globals)
		return
	end

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

	if (type(receiver) == "CRecipientFilter") then
		return receiver, true
	end

	if (istable(receiver)) then
		local humans = {}
		for i = 1, #receiver do
			local p = receiver[i]
			if (IsValid(p) and p:IsPlayer() and not p:IsBot()) then
				humans[#humans + 1] = p
			end
		end
		return humans, (#humans > 0)
	end

	if (not IsValid(receiver) or (receiver:IsPlayer() and receiver:IsBot())) then
		return nil, false
	end

	return receiver, true
end

function entityMeta:SendNetVar(key, receiver)
	local idx = self:EntIndex()
	if (idx < 0 or idx > 16383) then return end
	local target, shouldSend = FilterHumanReceiver(receiver)
	if (not shouldSend) then return end
	if (not target and not HasHumanPlayers()) then return end

	--netstream.Heavy(receiver, "nVar", self:EntIndex(), key, stored[self] and stored[self][key])
	net.Start("nVar")
		net.WriteUInt(idx, 14);
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
		if (not target and not HasHumanPlayers()) then return end

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
	local wasLocal = localKeys[self] and localKeys[self][key]
	if (not receiver and not wasLocal and !istable(value) and stored[self] and stored[self][key] == value) then return end
	if (not receiver and not wasLocal and value == nil and (not stored[self] or stored[self][key] == nil)) then return end

	if (localKeys[self]) then
		localKeys[self][key] = nil
	end

	stored[self] = stored[self] or {}
	stored[self][key] = value

	self:SendNetVar(key, receiver)
end

-- Batched SetNetVar: sets several keys on this entity and broadcasts one message instead of one per key.
-- pairs is an ordered array of {key, value}; unchanged keys are skipped.
function entityMeta:SetNetVars(pairs_)
	if (not istable(pairs_)) then return end
	local idx = self:EntIndex()
	if (idx < 0 or idx > 16383) then return end
	local changed, changedSet
	for i = 1, #pairs_ do
		local entry = pairs_[i]
		if (not istable(entry)) then continue end
		local key, value = entry[1], entry[2]
		if (checkBadType(key, value)) then continue end
		local wasLocal = localKeys[self] and localKeys[self][key]
		if (not wasLocal and !istable(value) and stored[self] and stored[self][key] == value) then continue end
		if (not wasLocal and value == nil and (not stored[self] or stored[self][key] == nil)) then continue end

		if (localKeys[self]) then
			localKeys[self][key] = nil
		end

		stored[self] = stored[self] or {}
		stored[self][key] = value

		changed = changed or {}
		changedSet = changedSet or {}
		if (not changedSet[key]) then
			changedSet[key] = true
			changed[#changed + 1] = key
		end
	end

	if (not changed) then return end

	local count = #changed
	if (count == 1) then
		self:SendNetVar(changed[1])
		return
	end

	if (not HasHumanPlayers()) then return end

	for offset = 1, count, 255 do
		local batchEnd = math.min(offset + 254, count)
		local batchCount = batchEnd - offset + 1
		if (batchCount == 1) then
			self:SendNetVar(changed[offset])
		else
			net.Start("nVarB")
				net.WriteUInt(idx, 14)
				net.WriteUInt(batchCount, 8)
				for i = offset, batchEnd do
					net.WriteString(changed[i])
					net.WriteType(stored[self][changed[i]])
				end
			net.Broadcast()
		end
	end
end

function entityMeta:SetLocalVar(key, value)
	if !self:IsPlayer() then
		self:SetNetVar(key, value);
	
		return;
	end

	if (checkBadType(key, value)) then return end
	local isLocal = localKeys[self] and localKeys[self][key]
	if (isLocal and !istable(value) and stored[self] and stored[self][key] == value) then return end
	if (isLocal and value == nil and (not stored[self] or stored[self][key] == nil)) then return end

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
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

--[[
netstream.Hook("nVar", function(index, key, value)
	stored[index] = stored[index] or {}
	stored[index][key] = value
end)

netstream.Hook("nDel", function(index)
	stored[index] = nil
end)

netstream.Hook("nLcl", function(key, value)
	stored[LocalPlayer():EntIndex()] = stored[LocalPlayer():EntIndex()] or {}
	stored[LocalPlayer():EntIndex()][key] = value
end)

netstream.Hook("gVar", function(key, value)
	globals[key] = value
end)
]]--

local nVarsSynced = false
local gVarsSynced = false
local deletedIndices = {}
local touchedKeys = {}
local touchedGlobals = {}
local pendingLocalVars = {}

local function FlushPendingLocalVars()
	local localPlayer = LocalPlayer()
	if not IsValid(localPlayer) or #pendingLocalVars == 0 then return end

	local index = localPlayer:EntIndex()
	stored[index] = stored[index] or {}

	for i = 1, #pendingLocalVars do
		local entry = pendingLocalVars[i]
		stored[index][entry[1]] = entry[2]
		if not nVarsSynced and touchedKeys then
			touchedKeys[index] = touchedKeys[index] or {}
			touchedKeys[index][entry[1]] = true
		end
	end

	pendingLocalVars = {}
end

hook.Add("InitPostEntity", "cwNetVarsInitialSync", FlushPendingLocalVars)

net.Receive("nVar", function()
	local index = net.ReadUInt(14);
	local key = net.ReadString()
	local value = net.ReadType()

	stored[index] = stored[index] or {}
	stored[index][key] = value

	if not nVarsSynced then
		if touchedKeys then
			touchedKeys[index] = touchedKeys[index] or {}
			touchedKeys[index][key] = true
		end
	end
end)

net.Receive("nDel", function()
	local index = net.ReadUInt(14);

	stored[index] = nil

	if not nVarsSynced and deletedIndices then
		deletedIndices[index] = true
	end
end)

net.Receive("nLcl", function()
	local key = net.ReadString()
	local value = net.ReadType()
	local localPlayer = LocalPlayer()
	if not IsValid(localPlayer) then
		pendingLocalVars[#pendingLocalVars + 1] = {key, value}
		return
	end

	FlushPendingLocalVars()

	local index = localPlayer:EntIndex()
	stored[index] = stored[index] or {}
	stored[index][key] = value

	if not nVarsSynced and touchedKeys then
		touchedKeys[index] = touchedKeys[index] or {}
		touchedKeys[index][key] = true
	end
end)

net.Receive("gVar", function()
	local key = net.ReadString()
	local value = net.ReadType()

	globals[key] = value

	if not gVarsSynced and touchedGlobals then
		touchedGlobals[key] = true
	end
end)

local function ApplyEntityVarsSync(batch)
	if not istable(batch) then return end

	local wasSynced = nVarsSynced

	-- Array of {entIndex, vars} pairs; pON drops sparse integer keys.
	for _, pair in ipairs(batch) do
		local index, data = istable(pair) and pair[1], istable(pair) and pair[2]
		if not isnumber(index) or not istable(data) then continue end
		if not wasSynced and deletedIndices and deletedIndices[index] then
			continue
		end

		stored[index] = stored[index] or {}
		local touched = (not wasSynced and touchedKeys and touchedKeys[index]) or nil

		if wasSynced then
			for k in pairs(stored[index]) do
				if data[k] == nil and (not touched or not touched[k]) then
					stored[index][k] = nil
				end
			end
		end

		for k, v in pairs(data) do
			if (not touched or not touched[k]) and (wasSynced or stored[index][k] == nil) then
				stored[index][k] = v
			end
		end
	end

	FlushPendingLocalVars()
	nVarsSynced = true
	deletedIndices = nil
	touchedKeys = nil
end

local function ApplyGlobalVarsSync(vars)
	if not istable(vars) then return end

	local wasSynced = gVarsSynced

	if wasSynced then
		for k in pairs(globals) do
			if vars[k] == nil then
				globals[k] = nil
			end
		end
	end

	for k, v in pairs(vars) do
		if (not wasSynced and touchedGlobals and touchedGlobals[k]) then
			continue
		end
		if wasSynced or globals[k] == nil then
			globals[k] = v
		end
	end

	gVarsSynced = true
	touchedGlobals = nil
end

local syncParts

net.Receive("cwVarsSync", function()
	local part = net.ReadUInt(16)
	local total = net.ReadUInt(16)
	local chunk = net.ReadData(net.ReadUInt(16))

	if part == 1 then
		syncParts = {}
	elseif not syncParts or #syncParts ~= part - 1 then
		syncParts = nil
		return
	end

	syncParts[part] = chunk
	if part < total then return end

	local raw = util.Decompress(table.concat(syncParts))
	syncParts = nil
	if not raw then return end

	local ok, snapshot = pcall(pon.decode, raw)
	if not ok or not istable(snapshot) then return end

	ApplyEntityVarsSync(snapshot[1])
	ApplyGlobalVarsSync(snapshot[2])
end)

function netvars.GetNetVar(key, default)
	local value = globals[key]

	return value != nil and value or default
end

function entityMeta:SetNetVar(key, value)
	local index = self:EntIndex()

	stored[index] = stored[index] or {}
	stored[index][key] = value
end

function entityMeta:SetLocalVar(key, value)
	self:SetNetVar(key, value);
end

function entityMeta:GetNetVar(key, default)
	local storedIndex = stored[self:EntIndex()];

	if (storedIndex) then
		return storedIndex[key] or default;
	end

	return default
end

playerMeta.GetNetVar = entityMeta.GetNetVar
playerMeta.GetLocalVar = entityMeta.GetNetVar

hook.Add("EntityRemoved", "nCleanUp", function(entity, bFullUpdate)
	if !bFullUpdate then
		local index = entity:EntIndex();
		
		if stored[index] then
			stored[index] = nil;
		end
	end
end)

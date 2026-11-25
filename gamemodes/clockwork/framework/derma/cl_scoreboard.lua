--[[
	Begotten III: Jesus Wept
	By: DETrooper, cash wednesday, gabs, alyousha35

	Other credits: kurozael, Alex Grist, Mr. Meow, zigbomb
--]]

local Clockwork = Clockwork;
local IsValid = IsValid;
local pairs = pairs;
local ScrH = ScrH;
local ScrW = ScrW;
local table = table;
local vgui = vgui;
local math = math;

local PANEL = {};

-- Called when the panel is initialized.
function PANEL:Init()
	self:SetSize(Clockwork.menu:GetWidth(), Clockwork.menu:GetHeight());

	self.panelList = vgui.Create("cwPanelList", self);
 	self.panelList:SetPadding(8);
 	self.panelList:SetSpacing(8);
 	self.panelList:SizeToContents();
	self.panelList:EnableVerticalScrollbar();
	
	Clockwork.scoreboard = self;
	Clockwork.scoreboard:Rebuild();
end;

-- Called to by the menu to get the width of the panel.
function PANEL:GetMenuWidth()
	return ScrW() * 0.3;
end;

-- A function to rebuild the panel.
function PANEL:Rebuild()
	self.panelList:Clear(true);
	
	local availableClasses = {};
	local classes = {};
	
	for _, v in _player.Iterator() do
		if (Clockwork.Client:IsAdmin()) then
			if (v:HasInitialized()) then
				local class = Clockwork.plugin:Call("GetPlayerScoreboardClass", v);
				
				if (class) then
					if (!availableClasses[class]) then
						availableClasses[class] = {};
					end;
					
					if (Clockwork.plugin:Call("PlayerShouldShowOnScoreboard", v)) then
						availableClasses[class][#availableClasses[class] + 1] = v;
					end;
				end;
			end;
		else
			if (v:HasInitialized() and v:IsAdmin()) then
				local class = Clockwork.plugin:Call("GetPlayerScoreboardClass", v);
				
				if (class) then
					if (!availableClasses[class]) then
						availableClasses[class] = {};
					end;
					
					if (Clockwork.plugin:Call("PlayerShouldShowOnScoreboard", v)) then
						availableClasses[class][#availableClasses[class] + 1] = v;
					end;
				end;
			end;
		end;
	end;
	
	for k, v in pairs(availableClasses) do
		table.sort(v, function(a, b)
			return Clockwork.plugin:Call("ScoreboardSortClassPlayers", k, a, b);
		end);
		
		if (#v > 0) then
			classes[#classes + 1] = {name = k, players = v};
		end;
	end;
	
	table.sort(classes, function(a, b)
		return a.name < b.name;
	end);
	
	if (table.Count(classes) > 0) then
		local label = vgui.Create("cwInfoText", self);
			label:SetText("Clicking a player's model icon may bring up some options.");
			label:SetInfoColor("blue");
		self.panelList:AddItem(label);
		
		for k, v in pairs(classes) do
			local characterForm = vgui.Create("DForm", self);
			local panelList = vgui.Create("DPanelList", self);
			
			for k2, v2 in pairs(v.players) do
				local dispFaction = v2:GetFaction();
				if (not Clockwork.Client:IsAdmin() and Clockwork.Client:GetFaction() ~= "Children of Satan") then
					local override = v2:GetNetVar("kinisgerOverride");
					if (override and override ~= "") then
						dispFaction = override;
					end;
				end;
				self.playerData = {
					avatarImage = true,
					steamName = v2:SteamName(),
					faction = dispFaction,
					player = v2,
					class = _team.GetName(v2:Team()),
					model = v2:GetModel(),
					skin = v2:GetSkin(),
					name = v2:Name()
				};
				
				panelList:AddItem(vgui.Create("cwScoreboardItem", self))
			end;
			
			self.panelList:AddItem(characterForm);
			
			panelList:SetAutoSize(true);
			panelList:SetPadding(4);
			panelList:SetSpacing(4);
			
			characterForm:SetName(v.name);
			characterForm:AddItem(panelList);
			characterForm:SetPadding(4); 
		end;
	else
		local label = vgui.Create("cwInfoText", self);
			label:SetText("There are no players to display.");
			label:SetInfoColor("orange");
		self.panelList:AddItem(label);
	end;
	
	self.panelList:InvalidateLayout(true);
end;

-- Called when the menu is opened.
function PANEL:OnMenuOpened()
	if (Clockwork.menu:IsPanelActive(self)) then
		self:Rebuild();
	end;
end;

-- Called when the panel is selected.
function PANEL:OnSelected()
	self:Rebuild();
end;

-- Called when the layout should be performed.
function PANEL:PerformLayout(w, h)
	self.panelList:StretchToParent(4, 28, 4, 4);
	self:SetSize(w, math.min(self.panelList.pnlCanvas:GetTall() + 32, ScrH() * 0.75));
end;

-- Called when the panel is painted.
function PANEL:Paint(w, h)
	derma.SkinHook("Paint", "Frame", self, w, h);

	return true;
end;

-- Called each frame.
function PANEL:Think() end;

vgui.Register("cwScoreboard", PANEL, "EditablePanel");

local PANEL = {};

-- Called when the panel is initialized.
function PANEL:Init()
	SCOREBOARD_PANEL = true;
		local parent = self:GetParent();
		local parentWide = (IsValid(parent) and parent:GetWide()) or ScrW();
		self:SetSize(parentWide, 32);
		
		local playerData = (IsValid(parent) and parent.playerData) or {};
		local targetPlayer = playerData.player;
		local info = {
			doesRecognise = (IsValid(targetPlayer) and Clockwork.player:DoesRecognise(targetPlayer)) or false,
			avatarImage = playerData.avatarImage,
			steamName = playerData.steamName or (IsValid(targetPlayer) and targetPlayer:SteamName()) or "Unknown",
			faction = playerData.faction or (IsValid(targetPlayer) and targetPlayer:GetFaction()) or "Unknown",
			player = targetPlayer,
			class = playerData.class or (IsValid(targetPlayer) and _team.GetName(targetPlayer:Team())) or "Unknown",
			model = playerData.model or (IsValid(targetPlayer) and targetPlayer:GetModel()) or "models/error.mdl",
			skin = playerData.skin or (IsValid(targetPlayer) and targetPlayer:GetSkin()) or 0,
			name = playerData.name or (IsValid(targetPlayer) and targetPlayer:Name()) or "Unknown"
		};
		
		if (IsValid(info.player)) then
			info.text = Clockwork.plugin:Call("GetPlayerScoreboardText", info.player);
			Clockwork.plugin:Call("ScoreboardAdjustPlayerInfo", info);
		else
			info.text = nil;
		end;
		
		self.toolTip = info.toolTip;
		self.player = info.player;
		
		self.nameLabel = vgui.Create("DLabel", self);
		self.nameLabel:SetText(info.name);
		self.nameLabel:SetDark(true);
		self.nameLabel:SizeToContents();
		self.nameLabel:SetTextColor(Color(255, 255, 255, 255));
		
		self.factionLabel = vgui.Create("DLabel", self); 
		self.factionLabel:SetText(info.faction);
		self.factionLabel:SizeToContents();
		self.factionLabel:SetDark(true);
		self.factionLabel:SetTextColor(Color(255, 255, 255, 255));
		
		if (type(info.text) == "string") then
			self.factionLabel:SetText(info.text);
			self.factionLabel:SizeToContents();
		end;
		
		if (info.doesRecognise) then
			self.spawnIcon = vgui.Create("cwSpawnIcon", self);
			self.spawnIcon:SetModel(info.model, info.skin);
			self.spawnIcon:SetSize(30, 30);
		else
			self.spawnIcon = vgui.Create("DImageButton", self);
			self.spawnIcon:SetImage("clockwork/unknown.png");
			self.spawnIcon:SetSize(30, 30);
		end;
		
		-- Called when the spawn icon is clicked.
		function self.spawnIcon.DoClick(spawnIcon)
			if (IsValid(info.player)) then
				local options = {};
				Clockwork.plugin:Call("GetPlayerScoreboardOptions", info.player, options);
				Clockwork.kernel:AddMenuFromData(nil, options);
			end;
		end;
		
		self.avatarImage = vgui.Create("AvatarImage", self);
		self.avatarImage:SetSize(30, 30);
		
		self.avatarButton = vgui.Create("DButton", self.avatarImage);
		self.avatarButton:Dock(FILL);
		self.avatarButton:SetText("");
		self.avatarButton:SetDrawBorder(false);
		self.avatarButton:SetDrawBackground(false);

		if (info.avatarImage) then
			local steamID = (IsValid(info.player) and info.player:SteamID()) or "Unknown";
			self.avatarButton:SetToolTip("This player's name is "..(info.steamName or "")..".\nThis player's Steam ID is "..steamID..".");
			self.avatarButton.DoClick = function(button)
				if (IsValid(info.player)) then
					info.player:ShowProfile();
				end;
			end;

			if (IsValid(info.player)) then
				self.avatarImage:SetPlayer(info.player);
			end;
		end;
		if (self.toolTip and IsValid(self.spawnIcon)) then
			self.spawnIcon:SetToolTip(self.toolTip);
		end;
	SCOREBOARD_PANEL = nil;
end;

-- Called each frame.
function PANEL:Think()
	if (!self.toolTip and IsValid(self.player) and IsValid(self.spawnIcon)) then
		local curTime = CurTime();
		if (!self.nextPingUpdate or self.nextPingUpdate < curTime) then
			self.nextPingUpdate = curTime + 2.0;
			self.spawnIcon:SetToolTip("This player's ping is "..self.player:Ping()..".");
		end;
	end;
end;
-- Called when the layout should be performed.
function PANEL:PerformLayout(w, h)
	if IsValid(self.factionLabel) then
		self.factionLabel:SizeToContents();
		self.factionLabel:SetPos(80, 30 - self.factionLabel:GetTall());
	end;
	
	if IsValid(self.spawnIcon) then
		self.spawnIcon:SetPos(1, 1);
		self.spawnIcon:SetSize(30, 30);
	end;
	
	if IsValid(self.avatarImage) then
		self.avatarImage:SetPos(40, 1);
		self.avatarImage:SetSize(30, 30);
	end;
	
	if IsValid(self.nameLabel) then
		self.nameLabel:SetPos(80, 2);
	end;
end;
local squa = Material("begotten/ui/infotextsquash.png")
local scra = Material("begotten/ui/generic_scratch.png")
function PANEL:Paint(w, h)
	local bgColor =  Clockwork.option:GetColor("information");
	local frameBorder = Color(120, 120, 120, 255);
	
	Clockwork.kernel:DrawWithTexture(scra, 1, 0, 0, w, h, frameBorder, 100);
	Clockwork.kernel:DrawWithTexture(squa, 0, 1, 1, 32 - 2, 32 - 2, Color(100, 100, 100), 125);
end;

vgui.Register("cwScoreboardItem", PANEL, "Panel");
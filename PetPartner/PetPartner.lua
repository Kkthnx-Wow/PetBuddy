local _, namespace = ...

-- Constants
local OPTION_ENABLE_ADDON = "enableAddon"
local OPTION_SUMMON_COOLDOWN = "summonCooldown"
local OPTION_SUMMON_ANNOUNCEMENTS = "showSummonAnnouncements"
local OPTION_SUMMON_FAVORITES_ONLY = "summonFavoritesOnly"
local INVIS_SPELLS = { 66, 11392, 3680 }
local CAMO_SPELLS = { 198783, 199483 }
local FOOD_SPELLS = { 430, 433, 167152, 160598, 160599 }

-- Variables
local summonedPetsCache = {}
local lastSummonTime = 0
local summoningInProgress = false
local playerStates = {
	playerIsDead = false,
	playerIsEating = false,
	playerIsFalling = false,
	playerIsFlying = false,
	playerIsInCombat = false,
	playerIsInVehicle = false,
	playerIsInvisible = false,
	playerIsLooting = false,
	playerIsSitting = false,
	playerIsStealth = false,
}
local playerAuras = {}

-- Spell name cache
local SPELL_NAME_CACHE = setmetatable({}, {
	__index = function(self, spellID)
		local spellInfo = C_Spell.GetSpellInfo(spellID)
		if spellInfo then
			rawset(self, spellID, spellInfo.name)
			return spellInfo.name
		end
		namespace:DebugPrint("Spell ID not found: " .. tostring(spellID))
		return nil
	end,
})

-- Debugging Utility
function namespace:DebugPrint(message, context)
	if namespace:GetOption("enableDebug") then
		local prefix = context and ("[" .. context .. "] ") or "[PetPartner Debug]: "
		namespace:Print(prefix .. message)
	end
end

-- Utility Functions
local function PlayerHasAura(spellIDOrList)
	if type(spellIDOrList) == "table" then
		for _, spellID in ipairs(spellIDOrList) do
			if playerAuras[SPELL_NAME_CACHE[spellID]] then
				return true
			end
		end
	else
		return playerAuras[SPELL_NAME_CACHE[spellIDOrList]] or false
	end
	return false
end

local function IsPlayerInIgnoredInstance()
	local inInstance, instanceType = IsInInstance()
	if not inInstance then
		return false
	end

	local instanceOptions = {
		party = "enableInInstances",
		raid = "enableInRaids",
		pvp = "enableInBattlegrounds",
		arena = "enableInBattlegrounds",
	}

	return not namespace:GetOption(instanceOptions[instanceType])
end

local function isPlayerInRestrictedState()
	local disallowedStates = {
		playerIsDead = "Player is dead",
		playerIsEating = "Player is eating",
		playerIsFalling = "Player is falling",
		playerIsFlying = "Player is flying",
		playerIsInCombat = "Player is in combat",
		playerIsInVehicle = "Player is in a vehicle",
		playerIsInvisible = "Player is invisible",
		playerIsLooting = "Player is looting",
		playerIsSitting = "Player is sitting",
		playerIsStealth = "Player is stealth",
	}

	for state, reason in pairs(disallowedStates) do
		if playerStates[state] then
			return true, reason
		end
	end

	return false
end

local function ResetSummonedPetsCache()
	namespace:DebugPrint("Resetting summoned pets cache.")
	wipe(summonedPetsCache)
end

local function FormatPetAnnouncement(petID)
	if not petID or petID == "0" then
		namespace:DebugPrint("Invalid petID detected. Skipping announcement.")
		return nil
	end

	local petLink = C_PetJournal.GetBattlePetLink(petID)
	if not petLink then
		namespace:DebugPrint("Failed to retrieve Battle Pet link. Skipping announcement.")
		return nil
	end

	local _, _, _, _, _, _, _, petName, icon, petType = C_PetJournal.GetPetInfoByPetID(petID)
	if not petName then
		namespace:DebugPrint("Invalid pet data. Skipping announcement.")
		return nil
	end

	local petTypeIcons = {
		[1] = "|TInterface\\Icons\\Icon_PetFamily_Humanoid:16|t",
		[2] = "|TInterface\\Icons\\Icon_PetFamily_Dragon:16|t",
		[3] = "|TInterface\\Icons\\Icon_PetFamily_Flying:16|t",
		[4] = "|TInterface\\Icons\\Icon_PetFamily_Undead:16|t",
		[5] = "|TInterface\\Icons\\Icon_PetFamily_Critter:16|t",
		[6] = "|TInterface\\Icons\\Icon_PetFamily_Magical:16|t",
		[7] = "|TInterface\\Icons\\Icon_PetFamily_Elemental:16|t",
		[8] = "|TInterface\\Icons\\Icon_PetFamily_Beast:16|t",
		[9] = "|TInterface\\Icons\\Icon_PetFamily_Water:16|t",
		[10] = "|TInterface\\Icons\\Icon_PetFamily_Mechanical:16|t",
	}
	local petTypeIcon = petTypeIcons[petType] or "|TInterface\\Icons\\INV_Misc_QuestionMark:16|t"
	local petIcon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"

	return string.format("has summoned: %s %s %s", petTypeIcon, "|T" .. petIcon .. ":16|t", petLink)
end

local function UpdatePlayerState(key, value)
	if playerStates[key] ~= value then
		playerStates[key] = value
		namespace:DebugPrint(key .. " updated to: " .. tostring(value))
	end
end

local function UpdateDynamicPlayerStates()
	UpdatePlayerState("playerIsFlying", IsFlying())
	UpdatePlayerState("playerIsFalling", IsFalling())
end

-- Pet Management
function namespace:DismissPet()
	local currentPetGUID = C_PetJournal.GetSummonedPetGUID()

	if currentPetGUID and currentPetGUID ~= "" then
		namespace:DebugPrint("Dismissing pet with GUID: " .. currentPetGUID)
		C_PetJournal.SummonPetByGUID(currentPetGUID)
		ResetSummonedPetsCache()
	else
		namespace:DebugPrint("No pet to dismiss.")
	end
end

local function CanSummonPet()
	local restricted, reason = isPlayerInRestrictedState()
	if restricted then
		return false, reason
	end

	if not namespace:GetOption(OPTION_ENABLE_ADDON) then
		return false, "Addon is disabled."
	end

	if IsPlayerInIgnoredInstance() then
		return false, "Ignored instance type for summoning."
	end

	if C_PetJournal.GetSummonedPetGUID() then
		return false, "A pet is already summoned."
	end

	local summonCooldown = namespace:GetOption(OPTION_SUMMON_COOLDOWN) or 1
	local timeSinceLastSummon = GetTime() - lastSummonTime
	if timeSinceLastSummon < summonCooldown then
		namespace:DebugPrint("Summon is on cooldown. Time left: " .. (summonCooldown - timeSinceLastSummon), "CanSummonPet")
		return false, "Summon is on cooldown."
	end

	return true
end

local function TrySummonPet()
	if summoningInProgress then
		namespace:DebugPrint("Summoning already in progress. Ignoring redundant calls.", "TrySummonPet")
		return
	end

	local canSummon, reason = CanSummonPet()
	if not canSummon then
		namespace:DebugPrint(reason, "TrySummonPet")
		return
	end

	summoningInProgress = true
	lastSummonTime = GetTime()

	namespace:DebugPrint("Processing summoning delay...", "TrySummonPet")
	C_Timer.After(2, function()
		summoningInProgress = false

		namespace:DebugPrint("Attempting to summon a pet after delay...", "TrySummonPet")

		local summonFavoritesOnly = namespace:GetOption(OPTION_SUMMON_FAVORITES_ONLY)
		local summonablePets = {}

		local numPets = C_PetJournal.GetNumPets()
		for i = 1, numPets do
			local petID, _, owned, _, _, favorite, _, _, _, _, companionID = C_PetJournal.GetPetInfoByIndex(i)
			local isSummonable, error = C_PetJournal.GetPetSummonInfo(petID)

			if petID and owned and isSummonable and error == Enum.PetJournalError.None and not PetPartnerBlocklistDB.npcs[companionID] then
				if (not summonFavoritesOnly or favorite) and not summonedPetsCache[petID] then
					table.insert(summonablePets, petID)
				end
			end
		end

		-- Summon pet
		if #summonablePets == 0 then
			namespace:DebugPrint("No valid pets found. Summoning random pet.", "TrySummonPet")
			C_PetJournal.SummonRandomPet(summonFavoritesOnly)
		else
			local petToSummon = summonablePets[math.random(#summonablePets)]
			C_PetJournal.SummonPetByGUID(petToSummon)
			summonedPetsCache[petToSummon] = true

			-- Print announcement
			if namespace:GetOption(OPTION_SUMMON_ANNOUNCEMENTS) then
				local announcement = FormatPetAnnouncement(petToSummon)
				if announcement then
					namespace:Print(announcement)
				end
			end
			namespace:DebugPrint("Summoned a new pet successfully!", "TrySummonPet")
		end
	end)
end

local function HandleSummoningEvents(event)
	namespace:DebugPrint("Event triggered: " .. (event or "Unknown"), "EventHandler")

	if summoningInProgress then
		namespace:DebugPrint("Summoning already in progress. Ignoring redundant calls.", "EventHandler")
		return
	end

	if CanSummonPet() then
		TrySummonPet()
	else
		namespace:DebugPrint("Cannot summon pet. Conditions not met.", "EventHandler")
	end
end

function namespace:UNIT_AURA(unit)
	if unit ~= "player" then
		return
	end

	namespace:DebugPrint("Updating player auras...")
	wipe(playerAuras)

	local i = 1
	while true do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL|PLAYER")
		if not aura then
			break
		end
		if aura.name then
			playerAuras[aura.name] = true
		end
		i = i + 1
	end

	UpdatePlayerState("playerIsEating", PlayerHasAura(FOOD_SPELLS))
	UpdatePlayerState("playerIsInvisible", PlayerHasAura(INVIS_SPELLS))
	UpdatePlayerState("playerIsInvisible", PlayerHasAura(CAMO_SPELLS))
	UpdatePlayerState("playerIsDead", PlayerHasAura(5384))

	HandleSummoningEvents("UNIT_AURA")
end

function namespace:PLAYER_REGEN_ENABLED()
	UpdatePlayerState("playerIsInCombat", false)
	HandleSummoningEvents("PLAYER_REGEN_ENABLED")
end

function namespace:PLAYER_REGEN_DISABLED()
	UpdatePlayerState("playerIsInCombat", true)
end

function namespace:PLAYER_ENTERING_WORLD(_, isReloadingUi)
	if isReloadingUi then
		ResetSummonedPetsCache()
		return
	end
	HandleSummoningEvents("PLAYER_ENTERING_WORLD")
end

function namespace:PLAYER_STARTED_MOVING()
	UpdatePlayerState("playerIsSitting", false)
	HandleSummoningEvents("PLAYER_STARTED_MOVING")
end

function namespace:PLAYER_FLAGS_CHANGED()
	local isAFK = UnitIsAFK("player")
	UpdatePlayerState("playerIsSitting", isAFK)
	HandleSummoningEvents("PLAYER_FLAGS_CHANGED")
end

function namespace:PLAYER_DEAD()
	UpdatePlayerState("playerIsDead", true)
	namespace:DebugPrint("Player is dead. Pet summoning disabled.")
end

function namespace:PLAYER_UNGHOST()
	UpdatePlayerState("playerIsDead", false)
	HandleSummoningEvents("PLAYER_UNGHOST")
end

function namespace:UPDATE_STEALTH()
	if IsStealthed() and namespace:GetOption("dismissWhileStealthed") then
		UpdatePlayerState("playerIsStealth", true)
		namespace:DebugPrint("Player is stealthed. Dismissing pet.")
		self:DismissPet()
	else
		UpdatePlayerState("playerIsStealth", false)
		HandleSummoningEvents("UPDATE_STEALTH")
	end
end

function namespace:UNIT_ENTERED_VEHICLE(unit)
	if unit == "player" then
		UpdatePlayerState("playerIsInVehicle", true)
	end
end

function namespace:UNIT_EXITED_VEHICLE(unit)
	if unit == "player" then
		UpdatePlayerState("playerIsInVehicle", false)
		HandleSummoningEvents("UNIT_EXITED_VEHICLE")
	end
end

function namespace:LOOT_OPENED()
	UpdatePlayerState("playerIsLooting", true)
	namespace:DebugPrint("Player is looting. Pet summoning disabled.")
end

function namespace:LOOT_CLOSED()
	UpdatePlayerState("playerIsLooting", false)
	HandleSummoningEvents("LOOT_CLOSED")
end

function namespace:PLAYER_UPDATE_RESTING()
	HandleSummoningEvents("PLAYER_UPDATE_RESTING")
end

-- Initialization
function namespace:OnLoad()
	namespace:DebugPrint("PetPartner addon loaded. Initializing...")
	ResetSummonedPetsCache()

	C_Timer.NewTicker(0.5, UpdateDynamicPlayerStates)
end

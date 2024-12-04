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
local playerStates = {
	isPlayerDead = false,
	playerIsEating = false,
	playerIsInvisible = false,
	playerIsInCombat = false,
	playerIsFlying = false,
	playerIsFalling = false,
	playerIsInVehicle = false,
	playerIsLooting = false,
	playerIsSitting = false,
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
function namespace:DebugPrint(message)
	if namespace:GetOption("enableDebug") then
		namespace:Print(message)
	end
end

-- Utility Functions
local function PlayerHasAura(spellID)
	local spellName = SPELL_NAME_CACHE[spellID]
	return spellName and playerAuras[spellName] or false
end

local function PlayerHasAuraInList(auraList)
	for _, spellID in ipairs(auraList) do
		if PlayerHasAura(spellID) then
			return true
		end
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

local function ResetSummonedPetsCache()
	namespace:DebugPrint("Resetting summoned pets cache.")
	wipe(summonedPetsCache)
end

local function ValidateBlocklistDB()
	local expectedKeys = { "npcs" }
	for _, key in ipairs(expectedKeys) do
		if not PetPartnerBlocklistDB[key] or type(PetPartnerBlocklistDB[key]) ~= "table" then
			namespace:DebugPrint("Blocklist database invalid. Initializing " .. key .. "...")
			PetPartnerBlocklistDB[key] = {}
		end
	end
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

local function UpdatePlayerVehicleState(unit)
	if unit == "player" then
		local inVehicle = UnitInVehicle("player")
		UpdatePlayerState("playerIsInVehicle", inVehicle)
		namespace:DebugPrint("Player vehicle state updated. In Vehicle: " .. tostring(inVehicle))
	end
end

local function UpdateDynamicPlayerStates()
	local isFlying = IsFlying() or false
	local isFalling = IsFalling() or false

	if playerStates.playerIsFlying ~= isFlying then
		UpdatePlayerState("playerIsFlying", isFlying)
	end

	if playerStates.playerIsFalling ~= isFalling then
		UpdatePlayerState("playerIsFalling", isFalling)
	end
end

local function LogPlayerStates()
	namespace:DebugPrint("Player States: " .. table.concat({
		"Dead = " .. tostring(playerStates.isPlayerDead),
		"Eating = " .. tostring(playerStates.playerIsEating),
		"Invisible = " .. tostring(playerStates.playerIsInvisible),
		"InCombat = " .. tostring(playerStates.playerIsInCombat),
		"Flying = " .. tostring(playerStates.playerIsFlying),
		"Falling = " .. tostring(playerStates.playerIsFalling),
		"InVehicle = " .. tostring(playerStates.playerIsInVehicle),
		"Looting = " .. tostring(playerStates.playerIsLooting),
		"Sitting = " .. tostring(playerStates.playerIsSitting),
	}, ", "))
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

local function TrySummonPet()
	LogPlayerStates()

	local disallowedStates = {
		isPlayerDead = "Player is dead",
		playerIsEating = "Player is eating",
		playerIsInvisible = "Player is invisible",
		playerIsInCombat = "Player is in combat",
		playerIsFlying = "Player is flying",
		playerIsFalling = "Player is falling",
		playerIsInVehicle = "Player is in a vehicle",
		playerIsLooting = "Player is looting",
		playerIsSitting = "Player is sitting",
	}

	for state, reason in pairs(disallowedStates) do
		if playerStates[state] then
			namespace:DebugPrint("Cannot summon pet: " .. reason)
			return
		end
	end

	local summonCooldown = namespace:GetOption(OPTION_SUMMON_COOLDOWN) or 1
	if GetTime() - lastSummonTime < summonCooldown then
		namespace:DebugPrint("SummonPet is on cooldown. Ignoring redundant calls.")
		return
	end
	lastSummonTime = GetTime()

	if not namespace:GetOption(OPTION_ENABLE_ADDON) then
		namespace:DebugPrint("PetPartner is disabled.")
		return
	end

	if IsPlayerInIgnoredInstance() then
		namespace:DebugPrint("Ignored summoning pets in the current instance.")
		return
	end

	if C_PetJournal.GetSummonedPetGUID() then
		namespace:DebugPrint("A pet is already summoned.")
		return
	end

	namespace:DebugPrint("Processing summoning delay...")
	C_Timer.After(1, function()
		namespace:DebugPrint("Attempting to summon a pet after delay...")

		ValidateBlocklistDB()

		local numPets = C_PetJournal.GetNumPets()
		local blacklist = PetPartnerBlocklistDB.npcs or {}
		local summonFavoritesOnly = namespace:GetOption(OPTION_SUMMON_FAVORITES_ONLY)
		local summonablePets = {}

		for i = 1, numPets do
			local petID, _, owned, _, _, favorite, _, _, _, _, companionID = C_PetJournal.GetPetInfoByIndex(i)
			local isSummonable, error = C_PetJournal.GetPetSummonInfo(petID)

			if petID and owned and isSummonable and error == Enum.PetJournalError.None and not blacklist[companionID] then
				if (not summonFavoritesOnly or favorite) and not summonedPetsCache[petID] then
					table.insert(summonablePets, petID)
				end
			end
		end

		if #summonablePets == 0 then
			namespace:DebugPrint("No valid pets found in the custom filter. Summoning a random pet.")
			C_PetJournal.SummonRandomPet(summonFavoritesOnly)
			return
		end

		local petToSummon = summonablePets[math.random(#summonablePets)]
		C_PetJournal.SummonPetByGUID(petToSummon)
		summonedPetsCache[petToSummon] = true

		if namespace:GetOption(OPTION_SUMMON_ANNOUNCEMENTS) then
			local announcement = FormatPetAnnouncement(petToSummon)
			if announcement then
				namespace:Print(announcement)
			end
		end

		namespace:DebugPrint("Summoned a new pet successfully!")
	end)
end

-- 1. Aura Updates
function namespace:UNIT_AURA(unit)
	if unit ~= "player" then
		return
	end

	namespace:DebugPrint("Updating player auras...")
	wipe(playerAuras)

	local i = 1
	while true do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if not aura then
			break
		end
		if aura.name then
			playerAuras[aura.name] = true
		end
		i = i + 1
	end

	UpdatePlayerState("playerIsEating", PlayerHasAuraInList(FOOD_SPELLS))
	UpdatePlayerState("playerIsInvisible", PlayerHasAuraInList(INVIS_SPELLS))
	TrySummonPet()
end

-- 2. Combat States
function namespace:PLAYER_REGEN_DISABLED()
	UpdatePlayerState("playerIsInCombat", true)
end

function namespace:PLAYER_REGEN_ENABLED()
	UpdatePlayerState("playerIsInCombat", false)
	TrySummonPet()
end

-- 3. World States
function namespace:PLAYER_ENTERING_WORLD()
	if IsPlayerInIgnoredInstance() then
		namespace:DebugPrint("Player is in a restricted instance. Pet summoning is disabled.")
		return
	end
	namespace:DebugPrint("Player entering the world.")
	TrySummonPet()
end

function namespace:ZONE_CHANGED()
	TrySummonPet()
end

function namespace:ZONE_CHANGED_INDOORS()
	TrySummonPet()
end

function namespace:ZONE_CHANGED_NEW_AREA()
	TrySummonPet()
end

-- 4. Player Behavior
function namespace:PLAYER_STARTED_MOVING()
	UpdatePlayerState("playerIsSitting", false)
	namespace:DebugPrint("Player started moving. Sitting state updated to false.")
end

function namespace:PLAYER_FLAGS_CHANGED()
	if UnitIsAFK("player") and not playerStates.playerIsSitting then
		UpdatePlayerState("playerIsSitting", true)
		namespace:DebugPrint("Player is now sitting (AFK).")
	elseif not UnitIsAFK("player") and playerStates.playerIsSitting then
		UpdatePlayerState("playerIsSitting", false)
		namespace:DebugPrint("Player is no longer AFK. Sitting state updated to false.")
	end
end

-- 5. Player States
function namespace:PLAYER_DEAD()
	UpdatePlayerState("isPlayerDead", true)
end

function namespace:PLAYER_UNGHOST()
	UpdatePlayerState("isPlayerDead", false)
	TrySummonPet()
end

function namespace:UPDATE_STEALTH()
	local dismissWhileStealthed = namespace:GetOption("dismissWhileStealthed")
	if IsStealthed() and not PlayerHasAuraInList(CAMO_SPELLS) then
		if dismissWhileStealthed then
			namespace:DebugPrint("Player is stealthed without camouflage. Dismissing summoned pet.")
			self:DismissPet()
		else
			namespace:DebugPrint("Player is stealthed but dismissing pets while stealthed is disabled.")
		end
	else
		TrySummonPet()
	end
end

-- 6. Interaction States
function namespace:UNIT_ENTERED_VEHICLE(unit)
	if unit == "player" then
		UpdatePlayerVehicleState(unit)
	end
end

function namespace:UNIT_EXITED_VEHICLE(unit)
	if unit == "player" then
		UpdatePlayerVehicleState(unit)
		if not playerStates.playerIsInVehicle then
			TrySummonPet()
		end
	end
end

function namespace:LOOT_OPENED()
	UpdatePlayerState("playerIsLooting", true)
end

function namespace:LOOT_CLOSED()
	UpdatePlayerState("playerIsLooting", false)
	TrySummonPet()
end

function namespace:PLAYER_UPDATE_RESTING()
	TrySummonPet()
end

function namespace:OnLoad()
	namespace:DebugPrint("PetPartner addon loaded. Initializing...")
	ValidateBlocklistDB()
	ResetSummonedPetsCache()

	C_Timer.NewTicker(0.5, UpdateDynamicPlayerStates)
end

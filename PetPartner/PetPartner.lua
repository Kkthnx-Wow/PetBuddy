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
local isPlayerDead = false
local playerIsEating = false
local playerIsInvisible = false
local playerIsInCombat = false
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

-- Check if the player has a specific aura
local function PlayerHasAura(spellID)
	local spellName = SPELL_NAME_CACHE[spellID]
	return spellName and playerAuras[spellName] or false
end

-- Check if the player has an aura from a given list
local function PlayerHasAuraInList(auraList)
	for _, spellID in ipairs(auraList) do
		if PlayerHasAura(spellID) then
			return true
		end
	end
	return false
end

-- Check if the player is in a restricted instance
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

-- Reset the summoned pets cache
local function ResetSummonedPetsCache()
	namespace:DebugPrint("Resetting summoned pets cache.")
	wipe(summonedPetsCache)
end

-- Validate the blocklist database
local function ValidateBlocklistDB()
	if not PetPartnerBlocklistDB or type(PetPartnerBlocklistDB.pets) ~= "table" then
		namespace:DebugPrint("Blocklist database invalid. Initializing...")
		PetPartnerBlocklistDB = { pets = {} }
	end
end

-- Format a pet announcement message
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

	return string.format("PetPartner has summoned: %s %s %s", petTypeIcon, "|T" .. petIcon .. ":16|t", petLink)
end

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
	if isPlayerDead or playerIsEating or playerIsInvisible or playerIsInCombat or IsFlying() then
		namespace:DebugPrint("Cannot summon pet. Dead: " .. tostring(isPlayerDead) .. ", Eating: " .. tostring(playerIsEating) .. ", Invisible: " .. tostring(playerIsInvisible) .. ", In Combat: " .. tostring(playerIsInCombat) .. ", Flying: " .. tostring(IsFlying()))
		return
	end

	local summonCooldown = namespace:GetOption(OPTION_SUMMON_COOLDOWN) or 1
	local currentTime = GetTime()

	if currentTime - lastSummonTime < summonCooldown then
		namespace:DebugPrint("SummonPet is on cooldown. Ignoring redundant calls.")
		return
	end

	lastSummonTime = currentTime

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

	namespace:DebugPrint("Attempting to summon a pet...")
	ValidateBlocklistDB()

	local numPets = C_PetJournal.GetNumPets()
	local blacklist = PetPartnerBlocklistDB.pets
	local summonablePets = {}
	local summonFavoritesOnly = namespace:GetOption(OPTION_SUMMON_FAVORITES_ONLY)

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

	local randomIndex = math.random(1, #summonablePets)
	local petToSummon = summonablePets[randomIndex]
	C_PetJournal.SummonPetByGUID(petToSummon)
	summonedPetsCache[petToSummon] = true

	if namespace:GetOption(OPTION_SUMMON_ANNOUNCEMENTS) then
		local announcement = FormatPetAnnouncement(petToSummon)
		if announcement then
			namespace:Print(announcement)
		end
	end

	namespace:DebugPrint("Summoned a new pet successfully!")
end

-- Event Handlers

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

	playerIsEating = PlayerHasAuraInList(FOOD_SPELLS)
	playerIsInvisible = PlayerHasAuraInList(INVIS_SPELLS)

	TrySummonPet()
end

function namespace:PLAYER_ENTERING_WORLD()
	if IsPlayerInIgnoredInstance() then
		namespace:DebugPrint("Player is in a restricted instance. Pet summoning is disabled.")
		return
	end

	namespace:DebugPrint("Player entering the world. Attempting to summon a pet.")
	TrySummonPet()
end

function namespace:PLAYER_DEAD()
	isPlayerDead = true
	namespace:DebugPrint("Player has died. Disabling pet summoning.")
end

function namespace:PLAYER_UNGHOST()
	isPlayerDead = false
	namespace:DebugPrint("Player has resurrected. Enabling pet summoning.")
	TrySummonPet()
end

function namespace:UPDATE_STEALTH()
	if IsStealthed() and not PlayerHasAuraInList(CAMO_SPELLS) then
		namespace:DebugPrint("Player is stealthed without camouflage. Dismissing summoned pet.")
		self:DismissPet()
	else
		TrySummonPet()
	end
end

function namespace:PLAYER_REGEN_DISABLED()
	playerIsInCombat = true
	namespace:DebugPrint("Combat started. Pet summoning is delayed.")
end

function namespace:PLAYER_REGEN_ENABLED()
	playerIsInCombat = false
	namespace:DebugPrint("Combat ended. Attempting to summon a pet.")
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

function namespace:PLAYER_UPDATE_RESTING()
	TrySummonPet()
end

function namespace:OnLoad()
	namespace:DebugPrint("PetPartner addon loaded. Initializing...")
	ValidateBlocklistDB()
	ResetSummonedPetsCache()
end

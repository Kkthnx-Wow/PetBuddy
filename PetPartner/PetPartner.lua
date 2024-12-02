local _, namespace = ...

local summonedPetsCache = {}
local lastSummonTime = 0

-- Debugging utility
function namespace:DebugPrint(message)
	if namespace:GetOption("enableDebug") then
		namespace:Print(message)
	end
end

-- Check if the addon is enabled
local function IsAddonEnabled()
	return namespace:GetOption("enableAddon")
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

-- Reset summoned pets cache
local function ResetSummonedPetsCache()
	namespace:DebugPrint("Resetting summoned pets cache.")
	summonedPetsCache = {}
end

-- Validate blocklist database
local function ValidateBlocklistDB()
	if not PetPartnerBlocklistDB or type(PetPartnerBlocklistDB.pets) ~= "table" then
		namespace:DebugPrint("Blocklist database invalid. Initializing...")
		PetPartnerBlocklistDB = { pets = {} }
	end
end

-- Summon a pet
local function SummonPet()
	local summonCooldown = namespace:GetOption("summonCooldown") or 1 -- Dynamically fetch cooldown
	local currentTime = GetTime()

	if currentTime - lastSummonTime < summonCooldown then
		namespace:DebugPrint("SummonPet is on cooldown. Ignoring redundant calls.")
		return
	end

	lastSummonTime = currentTime

	if not IsAddonEnabled() then
		namespace:DebugPrint("PetPartner is disabled.")
		return
	end

	if InCombatLockdown() then
		namespace:DebugPrint("Cannot summon a pet during combat.")
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
	local summonFavoritesOnly = namespace:GetOption("summonFavoritesOnly")

	for i = 1, numPets do
		local petID, _, owned, _, _, favorite = C_PetJournal.GetPetInfoByIndex(i)
		local isSummonable, error = C_PetJournal.GetPetSummonInfo(petID)

		if petID and owned and isSummonable and error == Enum.PetJournalError.None and not blacklist[petID] then
			if (not summonFavoritesOnly or favorite) and not summonedPetsCache[petID] then
				table.insert(summonablePets, petID)
			end
		end
	end

	if #summonablePets == 0 then
		ResetSummonedPetsCache()
		namespace:DebugPrint("No valid pets found. Summoning aborted.")
		return
	end

	local randomIndex = math.random(1, #summonablePets)
	local petToSummon = summonablePets[randomIndex]
	C_PetJournal.SummonPetByGUID(petToSummon)
	summonedPetsCache[petToSummon] = true
	namespace:DebugPrint("Summoned a new pet successfully!")
end

-- Event handling
function namespace:PLAYER_LOGIN()
	namespace:DebugPrint("Player logged in. Checking for pet summon...")
	SummonPet()
end

function namespace:PLAYER_REGEN_ENABLED()
	namespace:DebugPrint("Combat ended. Checking for pet summon...")
	SummonPet()
end

function namespace:PLAYER_REGEN_DISABLED()
	namespace:DebugPrint("Combat started. Delaying pet summon...")
end

function namespace:ZONE_CHANGED_NEW_AREA()
	namespace:DebugPrint("Zone changed. Checking for pet summon...")
	SummonPet()
end

-- OnLoad function to ensure settings are ready
function namespace:OnLoad()
	namespace:DebugPrint("PetPartner addon loaded. Validating settings...")
	ValidateBlocklistDB()
	ResetSummonedPetsCache()
end

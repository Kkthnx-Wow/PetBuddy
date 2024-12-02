-- Addon Name
local _, namespace = ...

-- Tracks combat state
local inCombat = false -- True if the player is in combat
local initialized = false -- Tracks if initialization has occurred

-- Debugging utility
local function DebugPrint(message, level)
	if namespace:GetOption("enableDebug") then
		level = level or "INFO" -- Default to INFO level
		namespace:Print(string.format("[%s] %s", level, message))
	end
end

-- Check if the player is in a restricted instance (e.g., dungeon, raid)
local function IsPlayerInIgnoredInstance()
	if namespace:GetOption("ignoreInInstances") then
		local inInstance, instanceType = IsInInstance()
		return inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "pvp")
	end
	return false
end

-- Check if a pet is currently summoned
local function IsPetSummoned()
	local summonedGUID = C_PetJournal.GetSummonedPetGUID()
	DebugPrint(string.format("Current summoned pet GUID: %s", summonedGUID or "None"), "DEBUG")
	return summonedGUID ~= nil
end

-- Filter summonable pets
local function GetSummonablePets(blacklist, favoritesOnly)
	local summonablePets = {}
	local numPets = C_PetJournal.GetNumPets()

	if numPets == 0 then
		DebugPrint("No pets found in the journal.", "WARNING")
		return summonablePets
	end

	for i = 1, numPets do
		local petID, _, owned, _, _, favorite = C_PetJournal.GetPetInfoByIndex(i)
		if petID and owned and not blacklist[petID] then
			local isSummonable, error, errorText = C_PetJournal.GetPetSummonInfo(petID)
			if isSummonable and error ~= Enum.PetJournalError.PetIsDead then
				if not favoritesOnly or favorite then
					table.insert(summonablePets, petID)
				end
			elseif error then
				DebugPrint(string.format("Pet ID %s cannot be summoned. Error: %s (%s)", petID, error, errorText or "No additional information"), "ERROR")
			end
		end
	end

	if #summonablePets == 0 then
		DebugPrint("No summonable pets available after filtering.", "WARNING")
	else
		DebugPrint(string.format("%d summonable pets found.", #summonablePets), "INFO")
	end

	return summonablePets
end

-- Summon a random pet
local function SummonPet()
	if InCombatLockdown() then
		DebugPrint("Cannot summon a pet during combat.", "INFO")
		return
	end

	if IsPlayerInIgnoredInstance() then
		DebugPrint("Ignored summoning pets in the current instance.", "INFO")
		return
	end

	if IsPetSummoned() then
		DebugPrint("A pet is already summoned.", "INFO")
		return
	end

	DebugPrint("Attempting to summon a pet...", "INFO")

	local blacklist = PetPartnerBlocklistDB and PetPartnerBlocklistDB.npcs or {}
	local favoritesOnly = namespace:GetOption("summonFavoritesOnly")
	local summonablePets = GetSummonablePets(blacklist, favoritesOnly)

	if #summonablePets > 0 then
		local randomIndex = math.random(1, #summonablePets)
		C_PetJournal.SummonPetByGUID(summonablePets[randomIndex])
		DebugPrint("Summoned a random pet successfully!", "SUCCESS")
	else
		DebugPrint("No summonable pets available.", "ERROR")
	end
end

-- Unified summon check
local function CheckAndSummonPet(triggerEvent)
	if inCombat then
		DebugPrint("Cannot process summon checks while in combat.", "INFO")
		return
	end

	DebugPrint(string.format("Processing summon check for event: %s", triggerEvent))
	C_Timer.After(2, SummonPet)
end

-- Event Handlers
function namespace:PLAYER_ENTERING_WORLD()
	if initialized then
		DebugPrint("PLAYER_ENTERING_WORLD fired after initialization, skipping additional handling.")
		return
	end

	initialized = true -- Mark initialization as complete
	DebugPrint("PLAYER_ENTERING_WORLD fired. Performing initial summon check.", "INFO")
	C_Timer.After(2, function()
		CheckAndSummonPet("PLAYER_ENTERING_WORLD")
	end)
end

function namespace:ZONE_CHANGED_NEW_AREA()
	DebugPrint("ZONE_CHANGED_NEW_AREA fired. Checking for pet summon.", "INFO")
	CheckAndSummonPet("ZONE_CHANGED_NEW_AREA")
end

function namespace:PLAYER_REGEN_ENABLED()
	inCombat = false -- Combat has ended
	DebugPrint("Combat ended. Delaying pet summon check.", "INFO")
	C_Timer.After(2, function()
		CheckAndSummonPet("PLAYER_REGEN_ENABLED")
	end)
end

function namespace:PLAYER_REGEN_DISABLED()
	inCombat = true -- Combat has started
	DebugPrint("Combat started. Deferring pet summon checks.", "INFO")
end

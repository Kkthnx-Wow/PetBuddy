-- Addon Name
local addonName, namespace = ...

-- Debugging utility
local function DebugPrint(message)
	if namespace:GetOption("enableDebug") then
		namespace:Print(message)
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
	return C_PetJournal.GetSummonedPetGUID() ~= nil
end

local function SummonPet()
	if InCombatLockdown() then
		DebugPrint("Cannot summon a pet during combat.")
		return
	end

	if IsPlayerInIgnoredInstance() then
		DebugPrint("Ignored summoning pets in the current instance.")
		return
	end

	if IsPetSummoned() then
		DebugPrint("A pet is already summoned.")
		return
	end

	DebugPrint("Attempting to summon a pet...")

	local numPets = C_PetJournal.GetNumPets()
	local blacklist = PetBuddyBlocklistDB.npcs

	if numPets > 0 then
		local summonablePets = {}

		for i = 1, numPets do
			local petID, _, owned, _, _, favorite = C_PetJournal.GetPetInfoByIndex(i)
			if owned and not blacklist[petID] then
				local isSummonable, error, errorText = C_PetJournal.GetPetSummonInfo(petID)

				if isSummonable and error ~= Enum.PetJournalError.PetIsDead then
					if namespace:GetOption("summonFavoritesOnly") then
						if favorite then
							table.insert(summonablePets, petID)
						end
					else
						table.insert(summonablePets, petID)
					end
				else
					if error == Enum.PetJournalError.PetIsDead then
						DebugPrint(string.format("Pet ID %s is dead and cannot be summoned. Skipping...", petID))
					elseif error then
						DebugPrint(string.format("Pet ID %s cannot be summoned. Error: %s (%s)", petID, error, errorText or "No additional information"))
					end
				end
			end
		end

		if #summonablePets > 0 then
			local randomIndex = math.random(1, #summonablePets)
			C_PetJournal.SummonPetByGUID(summonablePets[randomIndex])
			DebugPrint("Summoned a random pet successfully!")
		else
			DebugPrint("No summonable pets available.")
		end
	else
		DebugPrint("No pets found in the journal.")
	end
end

-- Event handling
function namespace:PLAYER_ENTERING_WORLD()
	DebugPrint("Player entered the world. Checking for pet summon...")
	SummonPet()
end

function namespace:PLAYER_REGEN_ENABLED()
	DebugPrint("Combat ended. Checking for pet summon...")
	SummonPet()
end

function namespace:PLAYER_REGEN_DISABLED()
	DebugPrint("Combat started. Delaying pet summon...")
end

function namespace:ZONE_CHANGED_NEW_AREA()
	DebugPrint("Zone changed. Checking for pet summon...")
	SummonPet()
end

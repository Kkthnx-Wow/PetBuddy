-- Addon Name
local _, namespace = ...

-- Initialize settings with Dashi
namespace:RegisterSettings("PetPartnerDB", {
	{
		key = "enableAddon",
		type = "toggle",
		title = "Enable PetPartner",
		tooltip = "Enable or disable the PetPartner addon.",
		default = true,
	},
	{
		key = "enableDebug",
		type = "toggle",
		title = "Enable Debugging",
		tooltip = "Toggle debugging messages for the addon.",
		default = true,
	},
	{
		key = "enableInInstances",
		type = "toggle",
		title = "Enable in Instances (Experimental)",
		tooltip = "Allow pet summoning in dungeons. This feature is experimental and may have unintended behavior.",
		default = false,
	},
	{
		key = "enableInRaids",
		type = "toggle",
		title = "Enable in Raids (Experimental)",
		tooltip = "Allow pet summoning in raid instances. This feature is experimental and may have unintended behavior.",
		default = false,
	},
	{
		key = "enableInBattlegrounds",
		type = "toggle",
		title = "Enable in Battlegrounds (Experimental)",
		tooltip = "Allow pet summoning in battlegrounds and arenas. This feature is experimental and may have unintended behavior.",
		default = false,
	},
	{
		key = "summonFavoritesOnly",
		type = "toggle",
		title = "Summon Favorites Only",
		tooltip = "Restrict summoning to favorite pets.",
		default = false,
	},
	{
		key = "summonCooldown",
		type = "slider",
		title = "Summon Cooldown",
		tooltip = "Set the cooldown time in seconds for summoning pets. This helps to throttle summon calls.",
		default = 1, -- Default cooldown of 1 second
		minValue = 0, -- Minimum cooldown of 0 seconds
		maxValue = 60, -- Maximum cooldown of 300 seconds
		valueStep = 1, -- Step increment for the cooldown value
		valueFormat = "%.0f seconds", -- Format for displaying the cooldown value
	},
})

-- Register Slash Command for Settings
namespace:RegisterSettingsSlash("/petpartner", "/pp")

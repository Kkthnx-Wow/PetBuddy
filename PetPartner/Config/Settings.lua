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
		default = false,
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
		default = 1,
		minValue = 0,
		maxValue = 60,
		valueStep = 1,
		valueFormat = "%.0f seconds",
	},
	{
		key = "showSummonAnnouncements",
		type = "toggle",
		title = "Show Summon Announcements",
		tooltip = "Enable or disable chat messages showing details about the summoned pet.",
		default = false,
	},
	{
		key = "dismissWhileStealthed",
		type = "toggle",
		title = "Dismiss Pets While Stealthed",
		tooltip = "Enable or disable dismissing pets while the player is stealthed.",
		default = true,
	},
	{
		key = "onlySummonInCities", -- New option
		type = "toggle",
		title = "Only Summon Pets in Cities", -- Title displayed in the settings UI
		tooltip = "Only allow pets to be summoned while in main cities.", -- Description displayed when hovering over the option
		default = false, -- Default value (unchecked)
	},
})

-- Register Slash Command for Settings
namespace:RegisterSettingsSlash("/petpartner", "/pp")

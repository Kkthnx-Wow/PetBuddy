-- Addon Name
local _, namespace = ...

-- Initialize settings with Dashi
namespace:RegisterSettings("PetPartnerDB", {
	{
		key = "enableDebug",
		type = "toggle",
		title = "Enable Debugging",
		tooltip = "Toggle debugging messages for the addon.",
		default = false,
	},
	{
		key = "ignoreInInstances",
		type = "toggle",
		title = "Ignore Summoning in Instances",
		tooltip = "Prevent pet summoning in restricted instances.",
		default = false,
	},
	{
		key = "summonFavoritesOnly",
		type = "toggle",
		title = "Summon Favorites Only",
		tooltip = "Restrict summoning to favorite pets.",
		default = false,
	},
})

-- Register Slash Command for Settings
namespace:RegisterSettingsSlash("/petpartner", "/pp")

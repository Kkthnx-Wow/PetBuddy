-- Addon Name
local addonName, namespace = ...

-- Initialize settings with Dashi
namespace:RegisterSettings("PetBuddyDB", {
	{
		key = "enableDebug",
		type = "toggle",
		title = "Enable Debugging",
		tooltip = "Toggle debugging messages for the addon.",
		default = true,
	},
	{
		key = "ignoreInInstances",
		type = "toggle",
		title = "Ignore Summoning in Instances",
		tooltip = "Prevent pet summoning in restricted instances.",
		default = true,
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
namespace:RegisterSettingsSlash("/petbuddy", "/pb")

local _, namespace = ...

-- Function to create the About section canvas
local function CreateAboutCanvas(canvas)
	-- Set the canvas size and default padding
	canvas:SetAllPoints(true)

	-- Title
	local title = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOP", canvas, "TOP", 0, -70)
	title:SetText("|cffFFD700Pet Partner|r") -- Gold text color

	-- Description
	local description = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	description:SetPoint("TOP", title, "BOTTOM", 0, -10)
	description:SetWidth(500)
	description:SetText("Pet Partner is your ultimate companion management addon, created by Kkthnx. It enhances your gameplay experience by automatically summoning and managing random or favorite non-combat pets during your adventures!")

	-- Features Heading
	local featuresHeading = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	featuresHeading:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -20)
	featuresHeading:SetText("|cffFFD700Features:|r")

	-- Features List
	local features = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	features:SetPoint("TOPLEFT", featuresHeading, "BOTTOMLEFT", 0, -10)
	features:SetWidth(500)
	features:SetText("- Automatically summon random pets during gameplay.\n" .. "- Restrict summoning to your favorite pets.\n" .. "- Blacklist pets you never want to summon.\n" .. "- Intuitive settings and options for customization.\n" .. "- Event-based summoning and instance avoidance.")

	-- Motivation Heading
	local motivationHeading = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	motivationHeading:SetPoint("TOPLEFT", features, "BOTTOMLEFT", 0, -20)
	motivationHeading:SetText("|cffFFD700Why Pet Partner Exists:|r")

	-- Motivation Text
	local motivation = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	motivation:SetPoint("TOPLEFT", motivationHeading, "BOTTOMLEFT", 0, -10)
	motivation:SetWidth(500)
	motivation:SetText("As a passionate player of World of Warcraft, Kkthnx wanted to create an addon that not only celebrates Azeroth's wonderful collection of pets but also simplifies their management. Pet Partner lets you focus on your adventures while your pets join in seamlessly!")

	-- Slash Commands Heading
	local commandsHeading = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	commandsHeading:SetPoint("TOPLEFT", motivation, "BOTTOMLEFT", 0, -20)
	commandsHeading:SetText("|cffFFD700Slash Commands:|r")

	-- Slash Commands List
	local commands = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	commands:SetPoint("TOPLEFT", commandsHeading, "BOTTOMLEFT", 0, -10)
	commands:SetWidth(500)
	commands:SetText("/petpartner or /pp - Open the Pet Partner settings menu.")

	-- Contributions Heading
	local contributionsHeading = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	contributionsHeading:SetPoint("TOPLEFT", commands, "BOTTOMLEFT", 0, -20)
	contributionsHeading:SetText("|cffFFD700Contributions:|r")

	-- PayPal Button
	local paypalButton = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
	paypalButton:SetPoint("TOPLEFT", contributionsHeading, "BOTTOMLEFT", 0, -10)
	paypalButton:SetSize(150, 25)
	paypalButton:SetText("Donate via PayPal")
	paypalButton:SetScript("OnClick", function()
		print("Visit this link to donate: https://www.paypal.com/paypalme/kkthnxtv")
	end)
	paypalButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Click to open the donation link.")
		GameTooltip:Show()
	end)
	paypalButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Feedback Button
	local feedbackButton = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
	feedbackButton:SetPoint("TOPLEFT", paypalButton, "BOTTOMLEFT", 0, -10)
	feedbackButton:SetSize(150, 25)
	feedbackButton:SetText("Report Feedback")
	feedbackButton:SetScript("OnClick", function()
		print("Visit the repository for feedback: https://github.com/Kkthnx-Wow/PetPartner")
	end)
	feedbackButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Click to open the feedback repository.")
		GameTooltip:Show()
	end)
	feedbackButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Support Heading
	local supportHeading = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	supportHeading:SetPoint("TOPLEFT", feedbackButton, "BOTTOMLEFT", 0, -20)
	supportHeading:SetText("|cffFFD700Support:|r")

	-- Support Details
	local support = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	support:SetPoint("TOPLEFT", supportHeading, "BOTTOMLEFT", 0, -10)
	support:SetWidth(500)
	support:SetText("Have feedback, ideas, or bugs to report? Click 'Report Feedback' or contact us directly. Thank you for using Pet Partner!")
end

-- Register the About canvas with the interface
namespace:RegisterSubSettingsCanvas("About Pet Partner", CreateAboutCanvas)

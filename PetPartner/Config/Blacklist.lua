local addonName, namespace = ...

-- Blacklist default setup
local blocklistDefaults = {
	npcs = {
		[54541] = true, -- Horde Balloon
		[54539] = true, -- Alliance Balloon
	},
}

local function createPopupDialog(name, hasItemFrame, onAlt)
	local dialog = {
		button1 = ADD,
		button2 = CANCEL,
		hasEditBox = true,
		hideOnEscape = true,
		timeout = 0,
		OnAccept = function(self)
			if self.data and self.data.callback then
				self.data.callback(self.editBox:GetText():trim())
			end
		end,
		OnShow = function(self)
			self.editBox:SetFocus()
			if hasItemFrame then
				self.editBox:SetNumeric(true)
				self.editBox:ClearAllPoints()
				self.editBox:SetPoint("BOTTOM", 0, 100)
			end
		end,
		OnHide = function(self)
			self.editBox:SetText("")
		end,
		EditBoxOnEnterPressed = function(editBox)
			local self = editBox:GetParent()
			if self.data and self.data.callback then
				self.data.callback(editBox:GetText():trim())
			end
			self:Hide()
		end,
		EditBoxOnEscapePressed = function(editBox)
			editBox:GetParent():Hide()
		end,
	}

	if hasItemFrame then
		dialog.hasItemFrame = true
		dialog.EditBoxOnTextChanged = function(editBox)
			local self = editBox:GetParent()
			local text = editBox:GetText():trim():match("[0-9]+")
			editBox:SetText(text or "")
			local itemID = C_Item.GetItemInfoInstant(tonumber(text) or "")
			if itemID then
				self.data = self.data or {}
				self.data.link = "|Hitem:" .. itemID .. "|h"
				self.ItemFrame:RetrieveInfo(self.data)
				self.ItemFrame:DisplayInfo(self.data.link, self.data.name, self.data.color, self.data.texture)
			else
				self.ItemFrame:DisplayInfo(nil, ERR_SOULBIND_INVALID_CONDUIT_ITEM, nil, [[Interface\Icons\INV_Misc_QuestionMark]])
			end
		end
	end

	if onAlt then
		dialog.button3 = TARGET
		dialog.OnAlt = function(self)
			local id = namespace:GetUnitID("target")
			if id and self.data and self.data.callback then
				self.data.callback(id)
			end
		end
	end

	StaticPopupDialogs[name] = dialog
end

-- Initialize popups
createPopupDialog(addonName .. "BlocklistPopup")
createPopupDialog(addonName .. "BlocklistItemPopup", true)
createPopupDialog(addonName .. "BlocklistTargetPopup", false, true)

-- Function to create Add Button
local function createAddButton(parent, title, callback, variant)
	local addButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	addButton:SetPoint("TOPRIGHT", -130, 40)
	addButton:SetSize(96, 22)
	addButton:SetText(ADD)
	addButton:SetScript("OnClick", function()
		local popupName = addonName .. "Blocklist" .. (variant or "") .. "Popup"
		local popup = StaticPopupDialogs[popupName]
		popup.text = title
		StaticPopup_Show(popupName, nil, nil, { callback = callback })
	end)
end

-- Constants
local BACKDROP = {
	bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
	tile = true,
	tileSize = 16,
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local CURSOR_HELP_TEXT = string.format("|A:NPE_RightClick:18:18|a %s", REMOVE)

-- Utility Functions
local function GetCreatureModel(npcID)
	local model = CreateFrame("PlayerModel")
	model:SetCreature(npcID)
	local creatureID = model:GetDisplayInfo()
	model:ClearModel()
	return creatureID and creatureID ~= 0 and creatureID or nil
end

local function GetCreatureName(npcID)
	local data = C_TooltipInfo.GetHyperlink("unit:Creature-0-0-0-0-" .. npcID .. "-0")
	return data and data.lines and data.lines[1] and data.lines[1].leftText or nil
end

-- Register Pet Blocklist Canvas
namespace:RegisterSubSettingsCanvas("Pet Blocklist", function(canvas)
	-- Data Cache
	local creatureIDs = setmetatable({}, {
		__index = function(self, npcID)
			local creatureID = GetCreatureModel(npcID)
			if creatureID then
				rawset(self, npcID, creatureID)
				return creatureID
			end
		end,
	})

	local creatureNames = setmetatable({}, {
		__index = function(self, npcID)
			local name = GetCreatureName(npcID)
			if name then
				rawset(self, npcID, name)
				return name
			end
		end,
	})

	-- Grid Setup
	local grid = namespace:CreateScrollGrid(canvas)
	grid:SetInsets(10, 10, 10, 20)
	grid:SetElementType("Button")
	grid:SetElementSize(64)
	grid:SetElementSpacing(4)

	-- Element Load Setup
	grid:SetElementOnLoad(function(element)
		element:RegisterForClicks("RightButtonUp")

		element.model = element:CreateTexture(nil, "ARTWORK")
		element.model:SetPoint("TOPLEFT", 4, -4)
		element.model:SetPoint("BOTTOMRIGHT", -4, 4)

		Mixin(element, BackdropTemplateMixin)
		element:SetBackdrop(BACKDROP)
		element:SetBackdropColor(0, 7 / 255, 34 / 255, 1)
		element:SetBackdropBorderColor(0.5, 0.5, 0.5)
	end)

	-- Element Update Setup
	grid:SetElementOnUpdate(function(element, data)
		local model = creatureIDs[data]
		if model then
			SetPortraitTextureFromCreatureDisplayID(element.model, model)
		else
			-- Retry loading model if unavailable
			local timer = C_Timer.NewTicker(1, function()
				local retryModel = creatureIDs[data]
				if retryModel then
					SetPortraitTextureFromCreatureDisplayID(element.model, retryModel)
					timer:Cancel()
				end
			end)
		end
	end)

	-- Element Click Setup
	grid:SetElementOnScript("OnClick", function(element)
		PetPartnerBlocklistDB.npcs[element.data] = nil -- Remove from blacklist
		grid:RemoveData(element.data)
	end)

	-- Element Tooltip Setup
	grid:SetElementOnScript("OnEnter", function(element)
		GameTooltip:SetOwner(element, "ANCHOR_TOPLEFT")
		GameTooltip:AddLine(creatureNames[element.data] or UNKNOWN, 1, 1, 1)
		GameTooltip:AddLine(element.data)
		GameTooltip:AddLine(CURSOR_HELP_TEXT, 1, 0, 0)
		GameTooltip:Show()
	end)

	-- Populate Grid with Data
	grid:AddDataByKeys(PetPartnerBlocklistDB.npcs)

	-- Default Reset Handler
	canvas:SetDefaultsHandler(function()
		PetPartnerBlocklistDB.npcs = CopyTable(blocklistDefaults.npcs)
		grid:ResetData()
		grid:AddDataByKeys(PetPartnerBlocklistDB.npcs)
	end)

	-- Add Button for Adding New NPCs
	createAddButton(canvas, namespace.L["Block a new Pet by ID or target"], function(data)
		local npcID = tonumber(data)
		if npcID then
			PetPartnerBlocklistDB.npcs[npcID] = true
			grid:AddData(npcID)
		end
	end, "Target")
end)

-- Initialization Function
function namespace:OnLoad()
	-- Initialize blocklist database if not present
	PetPartnerBlocklistDB = PetPartnerBlocklistDB or CopyTable(blocklistDefaults)

	-- Inject new defaults into existing blocklist database
	for kind, values in pairs(blocklistDefaults) do
		for key, value in pairs(values) do
			if PetPartnerBlocklistDB[kind][key] == nil then
				PetPartnerBlocklistDB[kind][key] = value
			end
		end
	end
end

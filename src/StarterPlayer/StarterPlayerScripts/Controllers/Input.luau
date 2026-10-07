--[[
	Input
	Keyboard shortcuts (PC) and gamepad menu navigation (console).
	Shortcuts never fire while typing in chat / text boxes.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local UI = script.Parent.Parent.UI
local WindowManager = require(UI.WindowManager)
local HUD = require(UI.HUD)
local Notifications = require(UI.Notifications)

local Input = {}

local SHORTCUTS = {
	[Enum.KeyCode.C] = "Collection",
	[Enum.KeyCode.B] = "Shop",
	[Enum.KeyCode.R] = "Rebirth",
	[Enum.KeyCode.Q] = "Quests",
	[Enum.KeyCode.I] = "Index",
	[Enum.KeyCode.L] = "Leaderboard",
	[Enum.KeyCode.P] = "Players",
	[Enum.KeyCode.G] = "Rewards",
	[Enum.KeyCode.Backquote] = "Settings",
}

function Input.Start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local window = SHORTCUTS[input.KeyCode]
		if window then
			WindowManager.Toggle(window)
			return
		end
		if input.KeyCode == Enum.KeyCode.H then
			local response = Net.Request("QuickTravel", "Home")
			if not response.Ok then
				Notifications.Toast(response.Message or "Can't travel right now", "Error")
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonSelect then
			-- Toggle gamepad focus on the bottom navigation bar.
			if GuiService.SelectedObject then
				GuiService.SelectedObject = nil
			else
				GuiService.SelectedObject = HUD.Buttons.Collection
			end
		end
	end)
end

return Input

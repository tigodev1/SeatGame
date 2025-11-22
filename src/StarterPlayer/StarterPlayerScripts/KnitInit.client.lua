--[[
	Client Knit Initialization
	This script loads all Knit controllers and starts the framework
--]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

--// Add Controllers manually
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local seatGameUI = playerGui:WaitForChild("SeatGameUI")
local UIController = require(seatGameUI:WaitForChild("UIController"))

--// Start Knit
Knit.Start():andThen(function()
	print("✓ Knit Started [Client]")
end):catch(function(err)
	warn("✗ Knit Start Failed [Client]:", err)
end)

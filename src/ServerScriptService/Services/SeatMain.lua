--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

--// Instances
local SeatGame = ReplicatedStorage:WaitForChild("SeatGame")
local SeatModels = SeatGame:WaitForChild("SeatModels")
local SeatsPlacing = Workspace:WaitForChild("SeatsPlacing")

--// Modules
local DataManager = require(script.DataManager)

--// Module
local SeatMain = {}

--// Functions
local function findPlayerSeatPosition(player)
	for _, position in ipairs(SeatsPlacing:GetChildren()) do
		local important = position:FindFirstChild("Important")
		if important then
			local occupant = important:FindFirstChild("Occupant")
			if occupant and occupant.Value == player.Name then
				return position
			end
		end
	end
	return nil
end

local function findAvailableSeatPosition()
	local seatPositions = SeatsPlacing:GetChildren()
	table.sort(seatPositions, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)

	for _, positionFolder in ipairs(seatPositions) do
		local important = positionFolder:FindFirstChild("Important")
		if important then
			local occupant = important:FindFirstChild("Occupant")
			if occupant and occupant.Value == "" then
				return positionFolder
			end
		end
	end

	return nil
end

local function createSeatAtPosition(seatPosition, player)
	local seatFolder = seatPosition:FindFirstChild("Seat")
	local anchorPoint = seatFolder:FindFirstChild("AnchorPoint")
	local equippedChairName = DataManager:GetEquippedChair(player)
	local seatModel = SeatModels:FindFirstChild(equippedChairName) or SeatModels:FindFirstChild("Default")
	local seatClone = seatModel:Clone()
	local seatPart = seatClone:FindFirstChild("Seat")

	seatClone.Parent = seatFolder

	-- Check for optional rotation offset
	local rotationOffset = seatModel:FindFirstChild("RotationOffset")
	local yRotation = 0
	if rotationOffset and rotationOffset:IsA("NumberValue") then
		yRotation = math.rad(rotationOffset.Value)
	end

	-- Position model at anchor point with matching rotation plus offset
	seatClone:PivotTo(anchorPoint.CFrame * CFrame.Angles(0, yRotation, 0))

	-- Get bounding box to find the actual lowest point
	local modelCFrame, modelSize = seatClone:GetBoundingBox()
	local lowestY = modelCFrame.Position.Y - (modelSize.Y / 2)
	local yAdjustment = anchorPoint.Position.Y - lowestY

	-- Apply vertical adjustment
	seatClone:PivotTo(anchorPoint.CFrame * CFrame.Angles(0, yRotation, 0) * CFrame.new(0, yAdjustment, 0))

	local important = seatPosition:FindFirstChild("Important")
	local occupant = important:FindFirstChild("Occupant")
	occupant.Value = player.Name

	return seatPart
end

local function setupPlayerControls(player, seatPart)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	humanoid.Died:Connect(function()
		humanoid.Health = humanoid.MaxHealth
	end)

	local connection
	connection = humanoid.StateChanged:Connect(function(oldState, newState)
		if newState ~= Enum.HumanoidStateType.Seated then
			if seatPart and seatPart.Parent then
				task.wait()
				seatPart:Sit(humanoid)
			else
				connection:Disconnect()
			end
		end
	end)
end

local function seatPlayer(player)
	local character = player.Character
	if not character then
		player.CharacterAdded:Wait()
		character = player.Character
	end

	local humanoid = character:WaitForChild("Humanoid")
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local seatPosition = findAvailableSeatPosition()

	if not seatPosition then return end

	local seatPart = createSeatAtPosition(seatPosition, player)

	task.wait(0.1)
	humanoidRootPart.CFrame = seatPart.CFrame + Vector3.new(0, 2, 0)
	task.wait(0.1)
	seatPart:Sit(humanoid)

	setupPlayerControls(player, seatPart)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		seatPlayer(player)
	end)

	if player.Character then
		task.wait(0.5)
		seatPlayer(player)
	end
end

function SeatMain:SwapPlayerChair(player)
	local seatPosition = findPlayerSeatPosition(player)
	if not seatPosition then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local seatFolder = seatPosition:FindFirstChild("Seat")
	if not seatFolder then return end

	local anchorPoint = seatFolder:FindFirstChild("AnchorPoint")
	if not anchorPoint then return end

	-- Remove old chair
	for _, obj in ipairs(seatFolder:GetChildren()) do
		if obj:IsA("Model") then
			obj:Destroy()
		end
	end

	-- Create new chair with equipped model
	local equippedChairName = DataManager:GetEquippedChair(player)
	local seatModel = SeatModels:FindFirstChild(equippedChairName) or SeatModels:FindFirstChild("Default")
	local seatClone = seatModel:Clone()
	local seatPart = seatClone:FindFirstChild("Seat")

	seatClone.Parent = seatFolder

	-- Check for optional rotation offset
	local rotationOffset = seatModel:FindFirstChild("RotationOffset")
	local yRotation = 0
	if rotationOffset and rotationOffset:IsA("NumberValue") then
		yRotation = math.rad(rotationOffset.Value)
	end

	-- Position model at anchor point with matching rotation plus offset
	seatClone:PivotTo(anchorPoint.CFrame * CFrame.Angles(0, yRotation, 0))

	-- Get bounding box to find the actual lowest point
	local modelCFrame, modelSize = seatClone:GetBoundingBox()
	local lowestY = modelCFrame.Position.Y - (modelSize.Y / 2)
	local yAdjustment = anchorPoint.Position.Y - lowestY

	-- Apply vertical adjustment
	seatClone:PivotTo(anchorPoint.CFrame * CFrame.Angles(0, yRotation, 0) * CFrame.new(0, yAdjustment, 0))

	-- Re-seat the player
	task.wait(0.1)
	seatPart:Sit(humanoid)
end

local function onPlayerRemoving(player)
	for _, position in ipairs(SeatsPlacing:GetChildren()) do
		local important = position:FindFirstChild("Important")
		if important then
			local occupant = important:FindFirstChild("Occupant")
			if occupant and occupant.Value == player.Name then
				occupant.Value = ""

				local seatFolder = position:FindFirstChild("Seat")
				if seatFolder then
					for _, obj in ipairs(seatFolder:GetChildren()) do
						if obj:IsA("Model") then
							obj:Destroy()
							break
						end
					end
				end

				break
			end
		end
	end
end

--// Listen for chair equip events
local chairEquippedEvent = SeatGame:WaitForChild("ChairEquipped")
chairEquippedEvent.Event:Connect(function(player, chairName)
	SeatMain:SwapPlayerChair(player)
end)

--// Initialize
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print("✓ SeatMain Initialized", {
	SeatPositions = #SeatsPlacing:GetChildren(),
	SeatModels = #SeatModels:GetChildren(),
	AutoSeating = "Enabled"
})

return SeatMain

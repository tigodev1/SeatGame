--!strict
-- SeatMain: Handles player seating system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SeatGame = ReplicatedStorage:WaitForChild("SeatGame")
local SeatModels = SeatGame:WaitForChild("SeatModels")
local SeatsPlacing = Workspace:WaitForChild("SeatsPlacing")

local occupiedSeats = {} -- Track which seat positions are occupied

-- Function to find an available seat position
local function findAvailableSeatPosition()
	local seatPositions = SeatsPlacing:GetChildren()

	-- Sort by name (assuming they're numbered 1, 2, 3, etc.)
	table.sort(seatPositions, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)

	-- Find the first unoccupied position
	for _, positionFolder in ipairs(seatPositions) do
		if not occupiedSeats[positionFolder.Name] then
			return positionFolder
		end
	end

	return nil -- No available seats
end

-- Function to create and place a seat at a position
local function createSeatAtPosition(seatPosition, player)
	local seatFolder = seatPosition:FindFirstChild("Seat")
	if not seatFolder then
		warn("No Seat folder found in position:", seatPosition.Name)
		return nil
	end

	local anchorPoint = seatFolder:FindFirstChild("AnchorPoint")
	if not anchorPoint then
		warn("No AnchorPoint found in:", seatPosition.Name)
		return nil
	end

	-- Clone the default seat model
	local defaultSeat = SeatModels:FindFirstChild("Default")
	if not defaultSeat then
		warn("No Default seat model found!")
		return nil
	end

	local seatClone = defaultSeat:Clone()

	-- Find the seat part within the model (assumes there's a Seat object)
	local seatPart = seatClone:FindFirstChildWhichIsA("Seat") or seatClone:FindFirstChild("Seat")

	if not seatPart then
		-- If no Seat found, look for VehicleSeat
		seatPart = seatClone:FindFirstChildWhichIsA("VehicleSeat")
	end

	if not seatPart then
		warn("No Seat or VehicleSeat found in Default model!")
		seatClone:Destroy()
		return nil
	end

	-- Position the seat model at the anchor point
	-- The seat should touch the baseplate, so align it properly
	seatClone:PivotTo(anchorPoint.CFrame)

	-- Parent to workspace
	seatClone.Parent = workspace

	-- Mark position as occupied
	occupiedSeats[seatPosition.Name] = player.UserId

	return seatPart
end

-- Function to disable player controls
local function setupPlayerControls(player)
	-- Wait for character
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	-- Disable jumping
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
end

-- Function to seat a player
local function seatPlayer(player)
	-- Wait for character
	local character = player.Character
	if not character then
		player.CharacterAdded:Wait()
		character = player.Character
	end

	local humanoid = character:WaitForChild("Humanoid")
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

	-- Find available seat position
	local seatPosition = findAvailableSeatPosition()
	if not seatPosition then
		warn("No available seat positions for player:", player.Name)
		return
	end

	-- Create seat at position
	local seatPart = createSeatAtPosition(seatPosition, player)
	if not seatPart then
		warn("Failed to create seat for player:", player.Name)
		return
	end

	-- Disable player controls
	setupPlayerControls(player)

	-- Wait a brief moment for the seat to be fully set up
	task.wait(0.1)

	-- Teleport player to seat and sit them down
	humanoidRootPart.CFrame = seatPart.CFrame + Vector3.new(0, 2, 0)
	task.wait(0.1)
	seatPart:Sit(humanoid)

	print("Player", player.Name, "seated at position", seatPosition.Name)
end

-- Handle player joining
local function onPlayerAdded(player)
	-- Wait for character
	player.CharacterAdded:Connect(function()
		task.wait(0.5) -- Small delay to ensure everything loads
		seatPlayer(player)
	end)

	-- If character already exists
	if player.Character then
		task.wait(0.5)
		seatPlayer(player)
	end
end

-- Handle player leaving
local function onPlayerRemoving(player)
	-- Find and remove their seat
	for positionName, userId in pairs(occupiedSeats) do
		if userId == player.UserId then
			occupiedSeats[positionName] = nil

			-- Clean up the seat model
			local position = SeatsPlacing:FindFirstChild(positionName)
			if position then
				for _, obj in ipairs(workspace:GetChildren()) do
					if obj:IsA("Model") and obj:FindFirstChild("Seat") then
						-- Check if this seat is at this position
						local seat = obj:FindFirstChildWhichIsA("Seat") or obj:FindFirstChildWhichIsA("VehicleSeat")
						if seat and seat.Occupant and seat.Occupant.Parent == player.Character then
							obj:Destroy()
							break
						end
					end
				end
			end

			break
		end
	end
end

-- Initialize
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle existing players (in case script runs after players join)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print("SeatMain initialized!")

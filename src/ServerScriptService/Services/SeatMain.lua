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
		return nil
	end

	local anchorPoint = seatFolder:FindFirstChild("AnchorPoint")
	if not anchorPoint then
		return nil
	end

	-- Clone the default seat model
	local defaultSeat = SeatModels:FindFirstChild("Default")
	if not defaultSeat then
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
		seatClone:Destroy()
		return nil
	end

	-- Parent to workspace first so we can get proper bounds
	seatClone.Parent = workspace

	-- Get the model's bounding box to calculate proper positioning
	local modelCFrame, modelSize = seatClone:GetBoundingBox()

	-- Calculate offset to place bottom of model at the anchor point level (baseplate level)
	-- The anchor point should be positioned at baseplate level
	local yOffset = modelSize.Y / 2

	-- Position the seat model so its bottom sits at the anchor point's Y level (on the baseplate)
	local targetCFrame = CFrame.new(
		anchorPoint.Position.X,
		anchorPoint.Position.Y + yOffset,  -- Center at anchor.Y + half height = bottom at anchor.Y
		anchorPoint.Position.Z
	)
	seatClone:PivotTo(targetCFrame)

	-- Mark position as occupied
	occupiedSeats[seatPosition.Name] = player.UserId

	return seatPart
end

-- Function to disable player controls and keep them seated
local function setupPlayerControls(player, seatPart)
	-- Wait for character
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	-- Disable all movement
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	-- Keep them seated continuously
	local connection
	connection = humanoid.StateChanged:Connect(function(oldState, newState)
		-- If they try to get up, force them back to sitting
		if newState ~= Enum.HumanoidStateType.Seated then
			if seatPart and seatPart.Parent then
				task.wait()
				seatPart:Sit(humanoid)
			else
				-- Seat was destroyed, disconnect
				connection:Disconnect()
			end
		end
	end)

	-- Store connection for cleanup
	character:SetAttribute("SeatConnection", true)
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
		-- No seats available, player will just spawn normally
		return
	end

	-- Create seat at position
	local seatPart = createSeatAtPosition(seatPosition, player)
	if not seatPart then
		return
	end

	-- Wait a brief moment for the seat to be fully set up
	task.wait(0.1)

	-- Teleport player to seat and sit them down
	humanoidRootPart.CFrame = seatPart.CFrame + Vector3.new(0, 2, 0)
	task.wait(0.1)
	seatPart:Sit(humanoid)

	-- Disable player controls after they're seated
	setupPlayerControls(player, seatPart)

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

-- Validate setup before starting
local function validateSetup()
	local issues = {}

	-- Check if SeatsPlacing has any children
	if #SeatsPlacing:GetChildren() == 0 then
		table.insert(issues, "⚠️ No seat positions found in Workspace > SeatsPlacing! Create numbered folders (1, 2, 3...)")
	else
		-- Check first position for proper structure
		local firstPos = SeatsPlacing:GetChildren()[1]
		if not firstPos:FindFirstChild("Seat") then
			table.insert(issues, "⚠️ Seat positions need a 'Seat' folder inside each numbered folder")
		elseif not firstPos.Seat:FindFirstChild("AnchorPoint") then
			table.insert(issues, "⚠️ Each Seat folder needs an 'AnchorPoint' part")
		end
	end

	-- Check for Default seat model
	if not SeatModels:FindFirstChild("Default") then
		table.insert(issues, "⚠️ No 'Default' seat model found in ReplicatedStorage > SeatGame > SeatModels!")
	else
		local defaultModel = SeatModels.Default
		local hasSeat = defaultModel:FindFirstChildWhichIsA("Seat") or defaultModel:FindFirstChildWhichIsA("VehicleSeat")
		if not hasSeat then
			table.insert(issues, "⚠️ Default model needs a Seat or VehicleSeat part inside it!")
		end
	end

	if #issues > 0 then
		warn("========================================")
		warn("🪑 SEAT GAME SETUP ISSUES DETECTED:")
		for _, issue in ipairs(issues) do
			warn(issue)
		end
		warn("========================================")
		warn("Players will NOT be seated until these issues are fixed!")
		return false
	end

	return true
end

-- Initialize
local setupValid = validateSetup()

if setupValid then
	print("✅ SeatMain initialized successfully!")

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle existing players (in case script runs after players join)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
else
	warn("❌ SeatMain NOT initialized - fix setup issues above")
end

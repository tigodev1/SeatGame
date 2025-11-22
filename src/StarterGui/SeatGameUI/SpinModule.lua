--[[
	SpinModule - Complete Rewrite
	Handles the slot machine style spinning animation
	Features:
	- Smooth idle scrolling
	- Weighted random seat selection
	- Satisfying spin animation with sound
	- Visual feedback and highlighting
--]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local SpinModule = {}

-- State
local isSpinning = false
local config = nil
local idleConnection = nil

-- Constants
local IDLE_SCROLL_SPEED = 20 -- pixels per second (slow and smooth)
local SPIN_DURATION = 4.5 -- seconds (fast start, slow stop)
local TOTAL_ITEMS = 200 -- items in the spin list
local WINNER_POSITION = 150 -- which slot the winner appears at
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 215, 0) -- gold
local HIGHLIGHT_THICKNESS = 5
local EASING_STYLE = Enum.EasingStyle.Exponential -- Very dramatic slow down
local EASING_DIRECTION = Enum.EasingDirection.Out

--[[
	Sound Helper
	Plays a sound once and cleans it up
--]]
local function playSound(sound)
	if not sound then
		warn("[SpinModule] Sound is nil")
		return
	end

	local clone = sound:Clone()
	clone.Parent = SoundService
	clone:Play()

	task.delay(clone.TimeLength + 0.5, function()
		if clone then
			clone:Destroy()
		end
	end)
end

--[[
	Idle Animation
	Slowly scrolls the list to the right
--]]
local function startIdleScroll()
	if idleConnection then return end

	print("[SpinModule] Starting idle scroll")

	idleConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if isSpinning or not config then
			return
		end

		-- Calculate new position
		local currentX = config.list.CanvasPosition.X
		local newX = currentX + (IDLE_SCROLL_SPEED * deltaTime)

		-- Get max scroll distance
		local maxX = config.list.AbsoluteCanvasSize.X - config.container.AbsoluteSize.X

		-- Loop back to start if we've reached the end
		if maxX > 0 and newX > maxX then
			newX = 0
		end

		-- Apply new position
		config.list.CanvasPosition = Vector2.new(newX, 0)
	end)
end

local function stopIdleScroll()
	if idleConnection then
		idleConnection:Disconnect()
		idleConnection = nil
		print("[SpinModule] Stopped idle scroll")
	end
end

--[[
	Clear List
	Removes all items from the spin list
--]]
local function clearList()
	for _, child in pairs(config.list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

--[[
	Populate List
	Fills the list with random seats and places the winner
--]]
local function populateList(winner)
	print("[SpinModule] Populating list with", TOTAL_ITEMS, "items")
	print("[SpinModule] Winner:", winner.Name, "at position", WINNER_POSITION)

	clearList()

	-- Create all items
	for i = 1, TOTAL_ITEMS do
		local model

		-- Place winner at designated position
		if i == WINNER_POSITION then
			model = winner
		else
			-- Random seat
			model = config.models[math.random(1, #config.models)]
		end

		-- Create display
		local gui = config.makeDisplay(model, config.rng)
		gui.LayoutOrder = i
		gui.Name = "Item_" .. i
		gui.Parent = config.list

		-- Yield every 20 items to prevent lag
		if i % 20 == 0 then
			task.wait()
		end
	end

	-- Wait for layout to update
	task.wait(0.1)

	print("[SpinModule] List populated. Canvas size:", config.list.AbsoluteCanvasSize)
end

--[[
	Calculate Target Position
	Determines where to scroll to center the winner under the picker
--]]
local function calculateTargetPosition()
	-- Get first item to measure width
	local firstItem = config.list:FindFirstChild("Item_1")
	if not firstItem then
		warn("[SpinModule] No items in list!")
		return 0
	end

	local itemWidth = firstItem.AbsoluteSize.X

	-- Get picker position relative to container
	local pickerCenterX = config.picker.AbsolutePosition.X + (config.picker.AbsoluteSize.X / 2)
	local containerStartX = config.container.AbsolutePosition.X
	local pickerOffsetFromContainer = pickerCenterX - containerStartX

	-- Calculate the X position of the winner item's center (in canvas coordinates)
	local winnerItemCenterX = (WINNER_POSITION - 1) * itemWidth + (itemWidth / 2)

	-- Calculate how much to scroll so the winner aligns with the picker
	local targetScroll = winnerItemCenterX - pickerOffsetFromContainer

	-- Clamp to valid scroll range
	local maxScroll = config.list.AbsoluteCanvasSize.X - config.container.AbsoluteSize.X
	targetScroll = math.clamp(targetScroll, 0, maxScroll)

	print("[SpinModule] Item width:", itemWidth)
	print("[SpinModule] Picker offset from container:", pickerOffsetFromContainer)
	print("[SpinModule] Winner item center:", winnerItemCenterX)
	print("[SpinModule] Target scroll:", targetScroll)
	print("[SpinModule] Max scroll:", maxScroll)

	return targetScroll
end

--[[
	Roll Sound Thread
	Plays click sound as items pass by
--]]
local function createSoundThread()
	local soundActive = true
	local lastPosition = 0
	local firstItem = config.list:FindFirstChild("Item_1")
	if not firstItem then return function() end end

	local itemWidth = firstItem.AbsoluteSize.X

	local thread = task.spawn(function()
		while soundActive and isSpinning do
			local currentPosition = config.list.CanvasPosition.X

			-- Play sound every time we pass an item width
			if currentPosition - lastPosition >= itemWidth then
				playSound(config.rollSound)
				lastPosition = currentPosition
			end

			task.wait()
		end
	end)

	-- Return cleanup function
	return function()
		soundActive = false
		task.cancel(thread)
	end
end

--[[
	Find Winner Element
	Locates the GUI element closest to the picker
--]]
local function findWinnerElement()
	local pickerCenterX = config.picker.AbsolutePosition.X + (config.picker.AbsoluteSize.X / 2)

	local closestItem = nil
	local closestDistance = math.huge

	for _, item in pairs(config.list:GetChildren()) do
		if item:IsA("GuiObject") then
			local itemCenterX = item.AbsolutePosition.X + (item.AbsoluteSize.X / 2)
			local distance = math.abs(itemCenterX - pickerCenterX)

			if distance < closestDistance then
				closestDistance = distance
				closestItem = item
			end
		end
	end

	return closestItem
end

--[[
	Highlight Winner
	Adds visual feedback to the winning item
--]]
local function highlightWinner(item)
	if not item then return end

	-- Create stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = HIGHLIGHT_COLOR
	stroke.Thickness = HIGHLIGHT_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = item

	-- Create glow effect by pulsing the thickness
	local pulseTween = TweenService:Create(
		stroke,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true),
		{Thickness = HIGHLIGHT_THICKNESS + 2}
	)
	pulseTween:Play()

	-- Clean up after delay
	task.delay(2, function()
		if pulseTween then
			pulseTween:Cancel()
		end
		if stroke then
			stroke:Destroy()
		end
	end)
end

--[[
	Get Item Name
	Extracts the seat name from a GUI item
--]]
local function getItemName(item)
	if not item then return nil end

	local nameLabel = item:FindFirstChild("Name")
	if nameLabel and nameLabel:IsA("TextLabel") then
		return nameLabel.Text
	end

	return nil
end

--[[
	Main Spin Function
	Executes the complete spin sequence
--]]
local function executeSpin()
	-- Prevent multiple spins
	if isSpinning then
		warn("[SpinModule] Already spinning!")
		return
	end

	print("[SpinModule] ========== SPIN START ==========")
	isSpinning = true
	stopIdleScroll()

	-- Update button state
	config.button.Active = false
	config.button.Text = "SPINNING..."

	-- Select winner
	local winner = config.rng:GetWeightedRandom()
	if not winner then
		warn("[SpinModule] Failed to get winner from RNG!")
		isSpinning = false
		config.button.Active = true
		config.button.Text = "SPIN"
		startIdleScroll()
		return
	end

	-- Build the list
	populateList(winner)

	-- Reset to start
	config.list.CanvasPosition = Vector2.new(0, 0)
	task.wait(0.2)

	-- Calculate where to scroll
	local targetPosition = calculateTargetPosition()

	-- Start sound effects
	local stopSounds = createSoundThread()

	-- Create and play tween with exponential easing for dramatic slow-down
	local spinTween = TweenService:Create(
		config.list,
		TweenInfo.new(
			SPIN_DURATION,
			EASING_STYLE,
			EASING_DIRECTION
		),
		{CanvasPosition = Vector2.new(targetPosition, 0)}
	)

	print("[SpinModule] Starting tween animation")
	spinTween:Play()
	spinTween.Completed:Wait()

	-- Stop sounds
	stopSounds()

	print("[SpinModule] Spin animation complete - landed!")

	-- Find winner IMMEDIATELY
	local winnerElement = findWinnerElement()
	local winnerName = getItemName(winnerElement)

	print("[SpinModule] Winner element:", winnerElement and winnerElement.Name or "nil")
	print("[SpinModule] Winner name:", winnerName or "unknown")

	-- INSTANT feedback - highlight and sound together
	highlightWinner(winnerElement)
	playSound(config.rewardSound)

	-- Save to player data (async, don't wait)
	if winnerName then
		task.spawn(function()
			local success, result = pcall(function()
				return config.data:InvokeServer("UnlockChair", winnerName)
			end)

			if success then
				print("[SpinModule] Successfully unlocked:", winnerName)
			else
				warn("[SpinModule] Failed to unlock chair:", result)
			end
		end)
	end

	-- Short pause before allowing next spin (reduced from 1 to 0.5)
	task.wait(0.5)
	config.button.Active = true
	config.button.Text = "SPIN"
	isSpinning = false

	print("[SpinModule] ========== SPIN END ==========")

	-- Restart idle
	startIdleScroll()
end

--[[
	Initialize
	Sets up the spin system with configuration
--]]
function SpinModule:Init(cfg)
	if config then
		warn("[SpinModule] Already initialized!")
		return
	end

	print("[SpinModule] Initializing...")

	-- Validate config
	assert(cfg.spinList, "Missing spinList")
	assert(cfg.spinContainer, "Missing spinContainer")
	assert(cfg.picker, "Missing picker")
	assert(cfg.spinButton, "Missing spinButton")
	assert(cfg.models, "Missing models")
	assert(cfg.rngModule, "Missing rngModule")
	assert(cfg.createDisplayFunc, "Missing createDisplayFunc")
	assert(cfg.dataRemote, "Missing dataRemote")

	-- Store config
	config = {
		list = cfg.spinList,
		container = cfg.spinContainer,
		picker = cfg.picker,
		button = cfg.spinButton,
		models = cfg.models,
		rollSound = cfg.rollSound,
		rewardSound = cfg.rewardSound,
		rng = cfg.rngModule,
		makeDisplay = cfg.createDisplayFunc,
		data = cfg.dataRemote
	}

	print("[SpinModule] Config stored. Models:", #config.models)

	-- Create initial preview items
	for i = 1, 40 do
		local randomModel = config.models[math.random(1, #config.models)]
		local gui = config.makeDisplay(randomModel, config.rng)
		gui.LayoutOrder = i
		gui.Parent = config.list
	end

	-- Wait for UI to layout
	task.wait(0.2)

	-- Connect spin button
	config.button.MouseButton1Click:Connect(executeSpin)

	-- Start idle animation
	startIdleScroll()

	print("[SpinModule] ✓ Initialization complete")
end

--[[
	Cleanup
	Stops all animations and disconnects events
--]]
function SpinModule:Cleanup()
	stopIdleScroll()
	clearList()
	config = nil
	isSpinning = false
	print("[SpinModule] Cleaned up")
end

return SpinModule

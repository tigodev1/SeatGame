--// Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Module
local SpinModule = {}

--// Config
local SPIN_DURATION = 5
local TOTAL_ITEMS = 200
local IDLE_SCROLL_SPEED = 18

--// State
local isInitialized = false
local isSpinning = false
local spinLocked = false

--// UI References
local spinList = nil
local spinContainer = nil
local picker = nil
local spinButton = nil

--// Game References
local models = nil
local rollSound = nil
local rewardSound = nil
local rngModule = nil
local createDisplayFunc = nil
local dataRemote = nil

--// Animation State
local currentTween = nil
local soundConnection = nil
local soundClones = {}
local idleConnection = nil

--// Sound Management
local function stopAllSounds()
	if soundConnection then
		soundConnection:Disconnect()
		soundConnection = nil
	end

	for _, sound in soundClones do
		if sound and sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end
	soundClones = {}
end

local function playSound(sound)
	local clone = sound:Clone()
	clone.Parent = SoundService
	clone:Play()
	table.insert(soundClones, clone)
end

local function fadeOutSounds(duration)
	if soundConnection then
		soundConnection:Disconnect()
		soundConnection = nil
	end

	local startTime = tick()
	local startVolumes = {}

	for i, sound in ipairs(soundClones) do
		if sound and sound.Parent then
			startVolumes[i] = sound.Volume
		end
	end

	local fadeConnection
	fadeConnection = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		local alpha = math.min(elapsed / duration, 1)

		for i, sound in ipairs(soundClones) do
			if sound and sound.Parent then
				sound.Volume = startVolumes[i] * (1 - alpha)
			end
		end

		if alpha >= 1 then
			fadeConnection:Disconnect()
			for _, sound in ipairs(soundClones) do
				if sound and sound.Parent then
					sound:Destroy()
				end
			end
			soundClones = {}
		end
	end)
end

--// Idle Animation
local function startIdleRoll()
	if idleConnection or not spinList then return end

	idleConnection = RunService.Heartbeat:Connect(function(dt)
		if not isSpinning and spinList then
			local maxScroll = spinList.AbsoluteCanvasSize.X - spinContainer.AbsoluteSize.X
			if maxScroll > 0 then
				local newPosition = spinList.CanvasPosition.X + (IDLE_SCROLL_SPEED * dt)
				if newPosition > maxScroll then
					newPosition = newPosition % maxScroll
				end
				spinList.CanvasPosition = Vector2.new(newPosition, 0)
			end
		end
	end)
end

local function stopIdleRoll()
	if idleConnection then
		idleConnection:Disconnect()
		idleConnection = nil
	end
end

--// Spin Logic
local function populateSpinList()
	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local wonSeat = rngModule:GetWeightedRandom()
	local winnerIndex = math.floor(TOTAL_ITEMS * 0.78)

	for i = 1, TOTAL_ITEMS do
		local model = (i == winnerIndex) and wonSeat or models[math.random(1, #models)]
		local display = createDisplayFunc(model, rngModule)
		display.LayoutOrder = i
		display.Parent = spinList

		if i % 20 == 0 then
			RunService.Heartbeat:Wait()
		end
	end

	return winnerIndex
end

local function performSpin()
	-- Immediate lock
	if spinLocked or isSpinning then
		warn("[SpinModule] Spin already in progress")
		return
	end

	spinLocked = true
	isSpinning = true
	stopIdleRoll()

	-- Update button
	spinButton.Active = false
	spinButton.Text = "SPINNING..."
	spinButton.BackgroundTransparency = 0.5

	-- Populate spin list
	spinList.CanvasPosition = Vector2.new(0, 0)
	local winnerIndex = populateSpinList()

	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()

	local firstItem = nil
	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") then
			firstItem = child
			break
		end
	end

	if not firstItem then
		isSpinning = false
		spinLocked = false
		spinButton.Active = true
		spinButton.Text = "SPIN"
		spinButton.BackgroundTransparency = 0
		startIdleRoll()
		return
	end

	local itemWidth = firstItem.AbsoluteSize.X
	local containerWidth = spinContainer.AbsoluteSize.X
	local targetPosition = (winnerIndex - 1) * itemWidth - (containerWidth / 2) + (itemWidth / 2)

	-- Sound system with dynamic interval
	local lastSoundPos = 0
	local baseSoundInterval = itemWidth * 0.7

	soundConnection = RunService.Heartbeat:Connect(function()
		if not isSpinning then return end

		local currentPos = spinList.CanvasPosition.X
		local distanceToTarget = targetPosition - currentPos
		local progress = currentPos / targetPosition

		-- Increase sound interval as we slow down
		local soundInterval = baseSoundInterval * (1 + progress * 0.8)

		if currentPos - lastSoundPos >= soundInterval then
			playSound(rollSound)
			lastSoundPos = currentPos
		end
	end)

	-- Main spin with smooth exponential deceleration
	local tweenInfo = TweenInfo.new(
		SPIN_DURATION,
		Enum.EasingStyle.Exponential,
		Enum.EasingDirection.Out
	)

	currentTween = TweenService:Create(spinList, tweenInfo, {
		CanvasPosition = Vector2.new(targetPosition, 0)
	})

	currentTween.Completed:Connect(function()
		-- Fade sounds smoothly
		fadeOutSounds(0.5)

		-- Find winner
		local pickerCenter = picker.AbsolutePosition.X + (picker.AbsoluteSize.X / 2)
		local closestItem = nil
		local closestDistance = math.huge

		for _, child in spinList:GetChildren() do
			if child:IsA("GuiObject") then
				local itemCenter = child.AbsolutePosition.X + (child.AbsoluteSize.X / 2)
				local distance = math.abs(itemCenter - pickerCenter)
				if distance < closestDistance then
					closestDistance = distance
					closestItem = child
				end
			end
		end

		-- Highlight winner with stroke
		if closestItem then
			local stroke = Instance.new("UIStroke")
			stroke.Name = "WinnerStroke"
			stroke.Color = Color3.fromRGB(255, 215, 0)
			stroke.Thickness = 3
			stroke.Transparency = 0
			stroke.Parent = closestItem

			local pulse = TweenService:Create(stroke,
				TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{Thickness = 5}
			)
			pulse:Play()

			task.delay(1.2, function()
				if stroke and stroke.Parent then
					pulse:Cancel()
					stroke:Destroy()
				end
			end)
		end

		-- Get winner name
		local wonSeatName = nil
		if closestItem then
			local nameLabel = closestItem:FindFirstChild("Name")
			if nameLabel then
				wonSeatName = nameLabel.Text
			end
		end

		-- Play reward sound
		playSound(rewardSound)

		-- Save to data (non-blocking)
		if wonSeatName then
			task.spawn(function()
				dataRemote:InvokeServer("UnlockChair", wonSeatName)
			end)
		end

		-- Reset button immediately
		spinButton.Active = true
		spinButton.Text = "SPIN"
		spinButton.BackgroundTransparency = 0

		-- Unlock
		isSpinning = false
		spinLocked = false

		-- Resume idle
		startIdleRoll()
	end)

	currentTween:Play()
end

--// Public Functions
function SpinModule:Init(config)
	if isInitialized then
		warn("[SpinModule] Already initialized")
		return
	end

	spinList = config.spinList
	spinContainer = config.spinContainer
	picker = config.picker
	spinButton = config.spinButton
	models = config.models
	rollSound = config.rollSound
	rewardSound = config.rewardSound
	rngModule = config.rngModule
	createDisplayFunc = config.createDisplayFunc
	dataRemote = config.dataRemote

	-- Populate initial preview
	local previewModels = {}
	for i = 1, 10 do
		previewModels[i] = models[math.random(1, #models)]
	end

	for loop = 1, 4 do
		for _, model in ipairs(previewModels) do
			local display = createDisplayFunc(model, rngModule)
			display.Parent = spinList
		end
		if loop < 4 then
			RunService.Heartbeat:Wait()
		end
	end

	spinList.CanvasPosition = Vector2.new(0, 0)

	-- Start idle animation
	startIdleRoll()

	-- Connect button
	spinButton.MouseButton1Click:Connect(performSpin)

	isInitialized = true
	print("[SpinModule] Initialized successfully")
end

function SpinModule:Cleanup()
	stopIdleRoll()
	stopAllSounds()

	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end

	isInitialized = false
	isSpinning = false
	spinLocked = false
end

return SpinModule

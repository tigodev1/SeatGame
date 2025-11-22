--// Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

--// Module
local SpinModule = {}

--// Config
local SPIN_DURATION = 5.5
local TOTAL_ITEMS = 220
local DECELERATION_DISTANCE = 8

--// State
local currentTween = nil
local soundConnection = nil
local soundClones = {}
local isSpinning = false

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

function SpinModule:Stop()
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end

	stopAllSounds()
	isSpinning = false
end

function SpinModule:IsSpinning()
	return isSpinning
end

function SpinModule:StartSpin(spinList, spinContainer, picker, models, rollSound, rngModule, createDisplayFunc, onComplete)
	if isSpinning then
		warn("[SpinModule] Spin already in progress!")
		return false
	end

	-- Lock immediately
	isSpinning = true

	self:Stop()

	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local wonSeat = rngModule:GetWeightedRandom()
	local winnerIndex = math.floor(TOTAL_ITEMS * 0.80)

	for i = 1, TOTAL_ITEMS do
		local model = (i == winnerIndex) and wonSeat or models[math.random(1, #models)]
		local display = createDisplayFunc(model, rngModule)
		display.LayoutOrder = i
		display.Parent = spinList

		if i % 25 == 0 then
			task.wait()
		end
	end

	spinList.CanvasPosition = Vector2.new(0, 0)
	task.wait(0.05)

	local firstItem = nil
	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") then
			firstItem = child
			break
		end
	end

	if not firstItem then
		isSpinning = false
		if onComplete then onComplete(nil) end
		return true
	end

	local itemWidth = firstItem.AbsoluteSize.X
	local containerWidth = spinContainer.AbsoluteSize.X
	local targetPosition = (winnerIndex - 1) * itemWidth - (containerWidth / 2) + (itemWidth / 2)

	-- Add deceleration zone
	local decelerationStart = targetPosition - (itemWidth * DECELERATION_DISTANCE)

	-- Sound system
	local lastSoundPos = 0
	local soundInterval = itemWidth * 0.75

	soundConnection = RunService.Heartbeat:Connect(function()
		local currentPos = spinList.CanvasPosition.X
		local distanceToTarget = targetPosition - currentPos

		-- Adjust sound interval based on proximity to target
		if distanceToTarget < itemWidth * 3 then
			soundInterval = itemWidth * 1.2
		end

		if currentPos - lastSoundPos >= soundInterval then
			playSound(rollSound)
			lastSoundPos = currentPos
		end
	end)

	-- Single smooth tween with exponential deceleration
	local tweenInfo = TweenInfo.new(
		SPIN_DURATION,
		Enum.EasingStyle.Exponential,
		Enum.EasingDirection.Out
	)

	currentTween = TweenService:Create(spinList, tweenInfo, {
		CanvasPosition = Vector2.new(targetPosition, 0)
	})

	currentTween.Completed:Connect(function()
		-- Fade out sounds smoothly
		fadeOutSounds(0.4)

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

		-- Highlight winner
		if closestItem then
			local highlight = Instance.new("UIStroke")
			highlight.Name = "WinnerHighlight"
			highlight.Color = Color3.fromRGB(255, 215, 0)
			highlight.Thickness = 4
			highlight.Transparency = 0
			highlight.Parent = closestItem

			local glow = TweenService:Create(highlight,
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true),
				{Thickness = 6, Transparency = 0.5}
			)
			glow:Play()

			task.delay(1.5, function()
				if highlight and highlight.Parent then
					glow:Cancel()
					highlight:Destroy()
				end
			end)
		end

		local wonSeatName = nil
		if closestItem then
			local nameLabel = closestItem:FindFirstChild("Name")
			if nameLabel then
				wonSeatName = nameLabel.Text
			end
		end

		isSpinning = false
		if onComplete then
			task.spawn(function()
				onComplete(wonSeatName)
			end)
		end
	end)

	currentTween:Play()
	return true
end

return SpinModule

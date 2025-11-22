--// Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

--// Module
local SpinModule = {}

--// Config
local SPIN_DURATION = 6
local TOTAL_ITEMS = 250
local ANTICIPATION_TIME = 0.4
local SETTLE_TIME = 0.5

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
		warn("[SpinModule] Already spinning!")
		return
	end
	isSpinning = true

	self:Stop()

	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local wonSeat = rngModule:GetWeightedRandom()
	local winnerIndex = math.floor(TOTAL_ITEMS * 0.82)

	for i = 1, TOTAL_ITEMS do
		local model = (i == winnerIndex) and wonSeat or models[math.random(1, #models)]
		local display = createDisplayFunc(model, rngModule)
		display.LayoutOrder = i
		display.Parent = spinList

		if i % 30 == 0 then
			task.wait()
		end
	end

	spinList.CanvasPosition = Vector2.new(0, 0)
	task.wait(0.1)

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
		return
	end

	local itemWidth = firstItem.AbsoluteSize.X
	local containerWidth = spinContainer.AbsoluteSize.X
	local targetPosition = (winnerIndex - 1) * itemWidth - (containerWidth / 2) + (itemWidth / 2)

	-- Anticipation phase (slow start)
	local anticipationTween = TweenService:Create(spinList,
		TweenInfo.new(ANTICIPATION_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{CanvasPosition = Vector2.new(itemWidth * 3, 0)}
	)
	anticipationTween:Play()
	anticipationTween.Completed:Wait()

	-- Main spin phase
	local lastSoundPos = 0
	soundConnection = RunService.Heartbeat:Connect(function()
		local currentPos = spinList.CanvasPosition.X
		if currentPos - lastSoundPos >= itemWidth * 0.8 then
			playSound(rollSound)
			lastSoundPos = currentPos
		end
	end)

	local mainTweenInfo = TweenInfo.new(
		SPIN_DURATION,
		Enum.EasingStyle.Cubic,
		Enum.EasingDirection.Out
	)

	currentTween = TweenService:Create(spinList, mainTweenInfo, {
		CanvasPosition = Vector2.new(targetPosition, 0)
	})

	currentTween.Completed:Connect(function()
		fadeOutSounds(SETTLE_TIME)

		-- Settle animation (elastic bounce)
		local settleTween = TweenService:Create(spinList,
			TweenInfo.new(SETTLE_TIME, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{CanvasPosition = Vector2.new(targetPosition, 0)}
		)
		settleTween:Play()

		task.wait(SETTLE_TIME)

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
			local highlight = Instance.new("Frame")
			highlight.Name = "WinnerHighlight"
			highlight.Size = UDim2.new(1, 10, 1, 10)
			highlight.Position = UDim2.new(0.5, 0, 0.5, 0)
			highlight.AnchorPoint = Vector2.new(0.5, 0.5)
			highlight.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
			highlight.BackgroundTransparency = 0.5
			highlight.BorderSizePixel = 0
			highlight.ZIndex = 10
			highlight.Parent = closestItem

			local glow = TweenService:Create(highlight,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true),
				{BackgroundTransparency = 0.8}
			)
			glow:Play()

			task.delay(2, function()
				if highlight and highlight.Parent then
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
		if onComplete then onComplete(wonSeatName) end
	end)

	currentTween:Play()
end

return SpinModule

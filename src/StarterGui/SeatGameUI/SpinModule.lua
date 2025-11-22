--// Services
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

--// Module
local SpinModule = {}

--// Config
local SPIN_DURATION = 4.5
local SETTLE_DURATION = 0.3
local ITEMS_PER_SET = 50
local NUMBER_OF_SETS = 4

--// State
local connection = nil
local soundClones = {}
local isSpinning = false

--// Easing Functions
local function easeOutCubic(t)
	return 1 - math.pow(1 - t, 3)
end

local function easeInOutQuart(t)
	if t < 0.5 then
		return 8 * t * t * t * t
	else
		return 1 - math.pow(-2 * t + 2, 4) / 2
	end
end

local function playSound(sound)
	local clone = sound:Clone()
	clone.Parent = SoundService
	clone:Play()
	table.insert(soundClones, clone)
	task.delay(sound.TimeLength, function()
		if clone and clone.Parent then
			clone:Destroy()
		end
		local index = table.find(soundClones, clone)
		if index then
			table.remove(soundClones, index)
		end
	end)
end

function SpinModule:Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end

	local sounds = soundClones
	soundClones = {}

	for _, sound in sounds do
		if sound and sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end

	isSpinning = false
end

function SpinModule:StartSpin(spinList, spinContainer, picker, models, rollSound, rngModule, createDisplayFunc, onComplete)
	if isSpinning then return end
	isSpinning = true

	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for i = 1, ITEMS_PER_SET * NUMBER_OF_SETS do
		local randomModel = models[math.random(1, #models)]
		local display = createDisplayFunc(randomModel, rngModule)
		display.LayoutOrder = i
		display.Parent = spinList

		if i % 10 == 0 then
			task.wait()
		end
	end

	task.wait(0.1)
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
	local targetIndex = math.random(140, 160)
	local basePosition = (targetIndex - 1) * itemWidth + (itemWidth / 2) - (containerWidth / 2)
	local overshoot = itemWidth * 1.5
	local targetScroll = basePosition + overshoot
	local startTime = os.clock()
	local currentItemIndex = -1
	local settleStartTime = nil
	local settleStartPosition = 0

	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime

		if settleStartTime then
			local settleElapsed = os.clock() - settleStartTime
			if settleElapsed >= SETTLE_DURATION then
				self:Stop()
				spinList.CanvasPosition = Vector2.new(basePosition, 0)

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

				local wonSeatName = nil
				if closestItem then
					local nameLabel = closestItem:FindFirstChild("Name")
					if nameLabel then
						wonSeatName = nameLabel.Text
					end
				end

				isSpinning = false
				if onComplete then onComplete(wonSeatName) end
				return
			end

			local settleProgress = settleElapsed / SETTLE_DURATION
			local easedProgress = easeOutCubic(settleProgress)
			local currentPosition = settleStartPosition + (basePosition - settleStartPosition) * easedProgress
			spinList.CanvasPosition = Vector2.new(currentPosition, 0)
			return
		end

		if elapsed >= SPIN_DURATION then
			settleStartTime = os.clock()
			settleStartPosition = spinList.CanvasPosition.X
			return
		end

		local scrollProgress = elapsed / SPIN_DURATION
		local easedProgress = easeInOutQuart(scrollProgress)
		local scrollPosition = easedProgress * targetScroll
		spinList.CanvasPosition = Vector2.new(scrollPosition, 0)

		local itemIndex = math.floor(scrollPosition / itemWidth)
		if itemIndex ~= currentItemIndex and itemIndex % 2 == 0 then
			currentItemIndex = itemIndex
			playSound(rollSound)
		elseif itemIndex ~= currentItemIndex then
			currentItemIndex = itemIndex
		end
	end)
end

return SpinModule

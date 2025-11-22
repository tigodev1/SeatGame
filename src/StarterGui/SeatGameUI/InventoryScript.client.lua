--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

task.spawn(function()
	pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
end)

--// Instances
local screenGui = script.Parent
local canvas = screenGui:WaitForChild("Canvas")
local buttonContainer = canvas:WaitForChild("ButtonContainer")
local inventoryButton = buttonContainer:WaitForChild("InventoryButton")
local spinButton = buttonContainer:WaitForChild("SpinButton")
local inventoryFrame = canvas:WaitForChild("Inventory")
local inventoryCloseButton = inventoryFrame:WaitForChild("CloseButton")
local spinningFrame = canvas:WaitForChild("SpinningFrame")
local spinningCloseButton = spinningFrame:WaitForChild("CloseButton")
local spinContainer = spinningFrame:WaitForChild("SpinContainer")
local spinList = spinContainer:WaitForChild("List")
local picker = spinContainer:WaitForChild("Picker")
local spinActionButton = spinningFrame:WaitForChild("Spin")
local list = inventoryFrame:WaitForChild("List")
local chairTemplate = script:WaitForChild("ChairTemplate")
local spinTemplate = script:WaitForChild("SpinTemplate")

local seatGame = ReplicatedStorage:WaitForChild("SeatGame")
local seatModels = seatGame:WaitForChild("SeatModels")
local soundsFolder = seatGame:WaitForChild("Sounds")
local hoverSound = soundsFolder:WaitForChild("Hover")
local clickSound = soundsFolder:WaitForChild("Click")
local rollSound = soundsFolder:WaitForChild("Roll")
local rewardSound = soundsFolder:WaitForChild("Reward")
local rngModule = require(seatGame.Modules.RNGModule)
local spinModule = require(script:WaitForChild("SpinModule"))
local dataRemote = seatGame:WaitForChild("DataRemote")

--// Config
local IDLE_SCROLL_SPEED = 18
local BUTTON_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUTTON_CLICK_INFO = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--// Variables
local isInventoryOpen = false
local isSpinLocked = false
local buttonSizes = {}
local idleRollConnection = nil

--// Utility Functions
local function playSound(sound)
	local clone = sound:Clone()
	clone.Parent = SoundService
	clone:Play()
	task.delay(sound.TimeLength, function()
		clone:Destroy()
	end)
end

local function scaleUDim2(udim2, scale)
	return UDim2.new(
		udim2.X.Scale * scale,
		udim2.X.Offset * scale,
		udim2.Y.Scale * scale,
		udim2.Y.Offset * scale
	)
end

local function showFrame(frame)
	frame.Visible = true
end

local function hideFrame(frame, callback)
	frame.Visible = false
	if callback then callback() end
end

--// Button Animation Setup
local function setupButtonAnimation(button)
	buttonSizes[button] = button.Size

	button.MouseEnter:Connect(function()
		if button.Active then
			playSound(hoverSound)
			TweenService:Create(button, BUTTON_TWEEN_INFO, {
				Size = scaleUDim2(buttonSizes[button], 1.06)
			}):Play()
		end
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, BUTTON_TWEEN_INFO, {
			Size = buttonSizes[button]
		}):Play()
	end)

	button.MouseButton1Down:Connect(function()
		if button.Active then
			TweenService:Create(button, BUTTON_CLICK_INFO, {
				Size = scaleUDim2(buttonSizes[button], 0.94)
			}):Play()
		end
	end)

	button.MouseButton1Up:Connect(function()
		if button.Active then
			TweenService:Create(button, BUTTON_CLICK_INFO, {
				Size = scaleUDim2(buttonSizes[button], 1.06)
			}):Play()
		end
	end)
end

--// Viewport Functions
local function createViewportCamera(viewport)
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return camera
end

local function setupChairInViewport(viewport, chairModel, rotating, isOwned)
	local camera = createViewportCamera(viewport)
	local clone = chairModel:Clone()
	clone.Parent = viewport

	if isOwned == false then
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") or descendant:IsA("MeshPart") then
				descendant.Color = Color3.fromRGB(20, 20, 20)
			end
		end
	end

	local cframe, size = clone:GetBoundingBox()
	local distance = math.max(size.X, size.Y, size.Z) * 1.0

	camera.CFrame = CFrame.new(cframe.Position + Vector3.new(distance, distance * 0.3, distance))
	camera.CFrame = CFrame.lookAt(camera.CFrame.Position, cframe.Position)

	if rotating then
		local angle = 0
		RunService.RenderStepped:Connect(function(dt)
			if clone and clone.Parent then
				angle = angle + (dt * 50)
				local rotatedCFrame = CFrame.new(cframe.Position) * CFrame.Angles(0, math.rad(angle), 0)
				clone:PivotTo(rotatedCFrame)
			end
		end)
	end
end

--// Display Creation
local function createChairDisplay(chairModel, isOwned)
	local template = chairTemplate:Clone()
	template.Visible = true

	local viewport = template:FindFirstChild("ViewportFrame")
	local nameLabel = template:FindFirstChild("Name")

	if viewport then
		setupChairInViewport(viewport, chairModel, true, isOwned)
	end

	if nameLabel then
		nameLabel.Text = chairModel.Name
	end

	template.Parent = list
end

local function createSpinDisplay(chairModel, rngMod)
	local template = spinTemplate:Clone()
	template.Visible = true

	local viewport = template:FindFirstChild("ViewportFrame")
	local nameLabel = template:FindFirstChild("Name")
	local rarityFrame = template:FindFirstChild("Rarity")

	if viewport then
		setupChairInViewport(viewport, chairModel, false, true)
	end

	if nameLabel then
		nameLabel.Text = chairModel.Name
	end

	if rarityFrame then
		local rarity = rngMod:GetSeatRarity(chairModel)
		rarityFrame.BackgroundColor3 = rngMod:GetRarityColor(rarity)
	end

	return template
end

--// Inventory Functions
local function populateInventory()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local ownedChairs = dataRemote:InvokeServer("GetOwnedChairs")

	for _, chairModel in seatModels:GetChildren() do
		if chairModel:IsA("Model") then
			local isOwned = table.find(ownedChairs, chairModel.Name) ~= nil
			createChairDisplay(chairModel, isOwned)
		end
	end
end

--// Spin Functions
local function populateSpinList()
	for _, child in spinList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local models = seatModels:GetChildren()
	local selectedSeats = {}

	for i = 1, 10 do
		selectedSeats[i] = models[math.random(1, #models)]
	end

	for loop = 1, 4 do
		for _, model in ipairs(selectedSeats) do
			local display = createSpinDisplay(model, rngModule)
			display.Parent = spinList
		end
		if loop < 4 then
			task.wait()
		end
	end

	spinList.CanvasPosition = Vector2.new(0, 0)
end

local function startIdleRoll()
	if idleRollConnection then return end

	idleRollConnection = RunService.Heartbeat:Connect(function(dt)
		if not spinModule:IsSpinning() and spinList then
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
	if idleRollConnection then
		idleRollConnection:Disconnect()
		idleRollConnection = nil
	end
end

local function performSpin()
	-- IMMEDIATE lock check - first line
	if isSpinLocked then
		warn("[Client] Spin locked!")
		return
	end

	-- Lock IMMEDIATELY before any other operations
	isSpinLocked = true

	-- Additional checks
	if spinModule:IsSpinning() then
		warn("[Client] Module reports spinning!")
		isSpinLocked = false
		return
	end

	if not spinActionButton.Active then
		warn("[Client] Button not active!")
		isSpinLocked = false
		return
	end

	stopIdleRoll()
	playSound(clickSound)

	spinActionButton.Active = false
	spinActionButton.Text = "SPINNING..."
	spinActionButton.BackgroundTransparency = 0.5

	local models = seatModels:GetChildren()

	-- StartSpin will handle its own locking internally
	local success = spinModule:StartSpin(spinList, spinContainer, picker, models, rollSound, rngModule, createSpinDisplay, function(wonSeatName)
		-- Play reward sound immediately
		playSound(rewardSound)

		-- Unlock chair in background
		if wonSeatName then
			task.spawn(function()
				dataRemote:InvokeServer("UnlockChair", wonSeatName)
			end)
		end

		-- Re-enable button immediately
		spinActionButton.Active = true
		spinActionButton.Text = "SPIN"
		spinActionButton.BackgroundTransparency = 0

		-- Unlock spin immediately
		isSpinLocked = false

		-- Resume idle
		startIdleRoll()
	end)

	-- If StartSpin failed, unlock immediately
	if not success then
		spinActionButton.Active = true
		spinActionButton.Text = "SPIN"
		spinActionButton.BackgroundTransparency = 0
		isSpinLocked = false
		startIdleRoll()
	end
end

--// UI Control Functions
local function closeInventory()
	isInventoryOpen = false
	hideFrame(inventoryFrame)
end

local function closeSpinning()
	hideFrame(spinningFrame, function()
		stopIdleRoll()
	end)
end

local function toggleInventory()
	playSound(clickSound)
	isInventoryOpen = not isInventoryOpen

	if isInventoryOpen then
		showFrame(inventoryFrame)
		populateInventory()
		if spinningFrame.Visible then
			hideFrame(spinningFrame)
		end
	else
		hideFrame(inventoryFrame)
	end
end

local function toggleSpinning()
	playSound(clickSound)
	local wasVisible = spinningFrame.Visible

	if not wasVisible then
		showFrame(spinningFrame)
		populateSpinList()
		startIdleRoll()
		if inventoryFrame.Visible then
			hideFrame(inventoryFrame)
		end
	else
		hideFrame(spinningFrame, function()
			stopIdleRoll()
		end)
	end
end

--// Initialize
inventoryFrame.Visible = false
spinningFrame.Visible = false

setupButtonAnimation(inventoryButton)
setupButtonAnimation(spinButton)
setupButtonAnimation(spinActionButton)
setupButtonAnimation(inventoryCloseButton)
setupButtonAnimation(spinningCloseButton)

inventoryButton.MouseButton1Click:Connect(toggleInventory)
spinButton.MouseButton1Click:Connect(toggleSpinning)
spinActionButton.MouseButton1Click:Connect(performSpin)
inventoryCloseButton.MouseButton1Click:Connect(function()
	playSound(clickSound)
	closeInventory()
end)
spinningCloseButton.MouseButton1Click:Connect(function()
	playSound(clickSound)
	closeSpinning()
end)

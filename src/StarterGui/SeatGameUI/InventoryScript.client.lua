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

--// UI
local gui = script.Parent
local canvas = gui:WaitForChild("Canvas")
local buttons = canvas:WaitForChild("ButtonContainer")
local invButton = buttons:WaitForChild("InventoryButton")
local spinButton = buttons:WaitForChild("SpinButton")
local invFrame = canvas:WaitForChild("Inventory")
local invClose = invFrame:WaitForChild("CloseButton")
local spinFrame = canvas:WaitForChild("SpinningFrame")
local spinClose = spinFrame:WaitForChild("CloseButton")
local spinContainer = spinFrame:WaitForChild("SpinContainer")
local spinList = spinContainer:WaitForChild("List")
local picker = spinContainer:WaitForChild("Picker")
local spinAction = spinFrame:WaitForChild("Spin")
local invList = invFrame:WaitForChild("List")
local chairTemplate = script:WaitForChild("ChairTemplate")
local spinTemplate = script:WaitForChild("SpinTemplate")

--// Game
local game = ReplicatedStorage:WaitForChild("SeatGame")
local seats = game:WaitForChild("SeatModels")
local sounds = game:WaitForChild("Sounds")
local hoverSound = sounds:WaitForChild("Hover")
local clickSound = sounds:WaitForChild("Click")
local rollSound = sounds:WaitForChild("Roll")
local rewardSound = sounds:WaitForChild("Reward")
local rng = require(game.Modules.RNGModule)
local spin = require(script:WaitForChild("SpinModule"))
local data = game:WaitForChild("DataRemote")

--// State
local invOpen = false
local buttonSizes = {}

--// Utils
local function playSound(sound)
	local s = sound:Clone()
	s.Parent = SoundService
	s:Play()
	task.delay(sound.TimeLength, function() s:Destroy() end)
end

local function scale(udim, s)
	return UDim2.new(udim.X.Scale * s, udim.X.Offset * s, udim.Y.Scale * s, udim.Y.Offset * s)
end

local function show(frame)
	frame.Visible = true
end

local function hide(frame)
	frame.Visible = false
end

--// Button Animations
local function setupButton(btn)
	buttonSizes[btn] = btn.Size
	local info = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	btn.MouseEnter:Connect(function()
		if btn.Active then
			playSound(hoverSound)
			TweenService:Create(btn, info, {Size = scale(buttonSizes[btn], 1.05)}):Play()
		end
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, info, {Size = buttonSizes[btn]}):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		if btn.Active then
			TweenService:Create(btn, info, {Size = scale(buttonSizes[btn], 0.95)}):Play()
		end
	end)

	btn.MouseButton1Up:Connect(function()
		if btn.Active then
			TweenService:Create(btn, info, {Size = scale(buttonSizes[btn], 1.05)}):Play()
		end
	end)
end

--// Viewport
local function createCamera(vp)
	local cam = Instance.new("Camera")
	cam.Parent = vp
	vp.CurrentCamera = cam
	return cam
end

local function setupViewport(vp, model, rotate, owned)
	local cam = createCamera(vp)
	local clone = model:Clone()
	clone.Parent = vp

	if not owned then
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				part.Color = Color3.fromRGB(20, 20, 20)
			end
		end
	end

	local cf, size = clone:GetBoundingBox()
	local dist = math.max(size.X, size.Y, size.Z) * 1.0
	cam.CFrame = CFrame.new(cf.Position + Vector3.new(dist, dist * 0.3, dist))
	cam.CFrame = CFrame.lookAt(cam.CFrame.Position, cf.Position)

	if rotate then
		local angle = 0
		RunService.RenderStepped:Connect(function(dt)
			if clone and clone.Parent then
				angle = angle + (dt * 50)
				clone:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, math.rad(angle), 0))
			end
		end)
	end
end

--// Displays
local function createChair(model, owned)
	local item = chairTemplate:Clone()
	item.Visible = true

	local vp = item:FindFirstChild("ViewportFrame")
	if vp then setupViewport(vp, model, true, owned) end

	local name = item:FindFirstChild("Name")
	if name then name.Text = model.Name end

	item.Parent = invList
end

local function createSpin(model, rngMod)
	local item = spinTemplate:Clone()
	item.Visible = true

	local vp = item:FindFirstChild("ViewportFrame")
	if vp then setupViewport(vp, model, false, true) end

	local name = item:FindFirstChild("Name")
	if name then name.Text = model.Name end

	local rarity = item:FindFirstChild("Rarity")
	if rarity then
		local r = rngMod:GetSeatRarity(model)
		rarity.BackgroundColor3 = rngMod:GetRarityColor(r)
	end

	return item
end

--// Inventory
local function updateInventory()
	for _, child in invList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local owned = data:InvokeServer("GetOwnedChairs")

	for _, model in seats:GetChildren() do
		if model:IsA("Model") then
			local has = table.find(owned, model.Name) ~= nil
			createChair(model, has)
		end
	end
end

--// UI Control
local function closeInv()
	invOpen = false
	hide(invFrame)
end

local function toggleInv()
	playSound(clickSound)
	invOpen = not invOpen

	if invOpen then
		show(invFrame)
		updateInventory()
		if spinFrame.Visible then hide(spinFrame) end
	else
		hide(invFrame)
	end
end

local function toggleSpin()
	playSound(clickSound)
	local vis = spinFrame.Visible

	if not vis then
		show(spinFrame)
		if invFrame.Visible then hide(invFrame) end
	else
		hide(spinFrame)
	end
end

--// Setup
invFrame.Visible = false
spinFrame.Visible = false

setupButton(invButton)
setupButton(spinButton)
setupButton(spinAction)
setupButton(invClose)
setupButton(spinClose)

invButton.MouseButton1Click:Connect(toggleInv)
spinButton.MouseButton1Click:Connect(toggleSpin)
invClose.MouseButton1Click:Connect(function()
	playSound(clickSound)
	closeInv()
end)
spinClose.MouseButton1Click:Connect(function()
	playSound(clickSound)
	hide(spinFrame)
end)

--// Init Spin
spin:Init({
	spinList = spinList,
	spinContainer = spinContainer,
	picker = picker,
	spinButton = spinAction,
	models = seats:GetChildren(),
	rollSound = rollSound,
	rewardSound = rewardSound,
	rngModule = rng,
	createDisplayFunc = createSpin,
	dataRemote = data
})

print("[UI] Ready")

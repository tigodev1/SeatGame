--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Module
local RNGModule = {}

--// Config
RNGModule.RarityWeights = {
	["Common"] = 50,
	["Uncommon"] = 30,
	["Rare"] = 12,
	["Epic"] = 5,
	["Legendary"] = 2.5,
	["Mythical"] = 0.5,
}

RNGModule.RarityColors = {
	["Common"] = Color3.fromRGB(180, 180, 180),      -- Gray
	["Uncommon"] = Color3.fromRGB(85, 255, 85),      -- Green
	["Rare"] = Color3.fromRGB(85, 170, 255),         -- Blue
	["Epic"] = Color3.fromRGB(170, 85, 255),         -- Purple
	["Legendary"] = Color3.fromRGB(255, 170, 0),     -- Gold
	["Mythical"] = Color3.fromRGB(255, 50, 150),     -- Pink/Magenta
}

--// Functions
function RNGModule:GetSeatModels()
	local seatGame = ReplicatedStorage:WaitForChild("SeatGame")
	local seatModels = seatGame:WaitForChild("SeatModels")
	local allModels = {}

	-- Get all models from rarity folders (exclude Miscellaneous)
	for _, folder in ipairs(seatModels:GetChildren()) do
		if folder:IsA("Folder") and folder.Name ~= "Miscellaneous" then
			for _, model in ipairs(folder:GetChildren()) do
				if model:IsA("Model") then
					table.insert(allModels, model)
				end
			end
		end
	end

	return allModels
end

function RNGModule:GetSeatRarity(seatModel)
	-- Rarity is determined by parent folder name
	local parent = seatModel.Parent
	if parent and parent:IsA("Folder") then
		local rarityName = parent.Name
		if self.RarityWeights[rarityName] then
			return rarityName
		end
	end
	return "Common"
end

function RNGModule:GetSeatsByRarity(rarityName)
	local seatGame = ReplicatedStorage:WaitForChild("SeatGame")
	local seatModels = seatGame:WaitForChild("SeatModels")
	local rarityFolder = seatModels:FindFirstChild(rarityName)

	if not rarityFolder then return {} end

	local seats = {}
	for _, model in ipairs(rarityFolder:GetChildren()) do
		if model:IsA("Model") then
			table.insert(seats, model)
		end
	end

	return seats
end

function RNGModule:GetWeightedRandom()
	-- Build weighted pool with proper ordering
	local rarityPool = {}
	for rarityName, weight in pairs(self.RarityWeights) do
		table.insert(rarityPool, {
			name = rarityName,
			weight = weight
		})
	end

	-- Sort by weight (highest to lowest) for consistency
	table.sort(rarityPool, function(a, b)
		return a.weight > b.weight
	end)

	-- Calculate total weight
	local totalWeight = 0
	for _, rarity in ipairs(rarityPool) do
		totalWeight = totalWeight + rarity.weight
	end

	-- Generate random number and select rarity
	local random = Random.new()
	local roll = random:NextNumber(0, totalWeight)

	local currentWeight = 0
	for _, rarity in ipairs(rarityPool) do
		currentWeight = currentWeight + rarity.weight
		if roll <= currentWeight then
			local seatsInRarity = self:GetSeatsByRarity(rarity.name)
			if #seatsInRarity > 0 then
				-- Randomly select a chair from this rarity
				local randomIndex = random:NextInteger(1, #seatsInRarity)
				return seatsInRarity[randomIndex]
			end
		end
	end

	-- Fallback to Common if something goes wrong
	local commonSeats = self:GetSeatsByRarity("Common")
	if #commonSeats > 0 then
		return commonSeats[random:NextInteger(1, #commonSeats)]
	end

	return nil
end

function RNGModule:GetRarityChance(rarityName)
	local weight = self.RarityWeights[rarityName]
	if not weight then return 0 end
	return weight
end

function RNGModule:GetRarityChancePercent(rarityName)
	local weight = self.RarityWeights[rarityName]
	if not weight then return 0 end

	local totalWeight = 0
	for _, w in pairs(self.RarityWeights) do
		totalWeight = totalWeight + w
	end

	return (weight / totalWeight) * 100
end

function RNGModule:GetRarityColor(rarityName)
	return self.RarityColors[rarityName] or Color3.fromRGB(255, 255, 255)
end

-- Print rarity chances on initialization
local totalWeight = 0
for _, weight in pairs(RNGModule.RarityWeights) do
	totalWeight = totalWeight + weight
end

print("✓ RNGModule Initialized")
print("  Rarity Chances:")
for rarityName, weight in pairs(RNGModule.RarityWeights) do
	local percentage = (weight / totalWeight) * 100
	print(string.format("    %s: %.2f%%", rarityName, percentage))
end

return RNGModule

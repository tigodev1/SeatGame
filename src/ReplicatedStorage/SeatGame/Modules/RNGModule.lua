--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Module
local RNGModule = {}

RNGModule.RarityWeights = {
	["Common"] = 50,
	["Uncommon"] = 30,
	["Rare"] = 12,
	["Epic"] = 5,
	["Legendary"] = 2.5,
	["Mythical"] = 0.5,
}

RNGModule.RarityColors = {
	["Common"] = Color3.fromRGB(180, 180, 180),
	["Uncommon"] = Color3.fromRGB(85, 255, 85),
	["Rare"] = Color3.fromRGB(85, 170, 255),
	["Epic"] = Color3.fromRGB(170, 85, 255),
	["Legendary"] = Color3.fromRGB(255, 170, 0),
	["Mythical"] = Color3.fromRGB(255, 50, 150),
}

function RNGModule:GetSeatModels()
	local seatGame = ReplicatedStorage:WaitForChild("SeatGame")
	local seatModels = seatGame:WaitForChild("SeatModels")
	local allModels = {}

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
	local totalWeight = 0
	for _, weight in pairs(self.RarityWeights) do
		totalWeight = totalWeight + weight
	end

	local random = Random.new()
	local roll = random:NextNumber(0, totalWeight)

	local selectedRarity = nil
	local currentWeight = 0

	for rarityName, weight in pairs(self.RarityWeights) do
		currentWeight = currentWeight + weight
		if roll <= currentWeight then
			selectedRarity = rarityName
			break
		end
	end

	if selectedRarity then
		local seatsInRarity = self:GetSeatsByRarity(selectedRarity)
		if #seatsInRarity > 0 then
			local randomIndex = random:NextInteger(1, #seatsInRarity)
			return seatsInRarity[randomIndex]
		else
			warn(string.format("[RNG] Rolled %s (%.2f%%) but folder is empty! Falling back to Common.", selectedRarity, (self.RarityWeights[selectedRarity] / totalWeight) * 100))
		end
	end

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

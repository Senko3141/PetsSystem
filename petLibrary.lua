-- PetLibrary
--[[
	Shared pet functions
]]

local replicatedStorage = game:GetService("ReplicatedStorage")
local marketPlaceService = game:GetService("MarketplaceService")

local modules = replicatedStorage:WaitForChild("Modules")
local petsFolder = modules.Shared.Pets

local library = {}

function library.getBestPets(allPets: any)
	local sorted = {}
	for petId: string, _ in allPets do
		local trueName = petId:split("/")[1]
		if trueName then
			local foundFolder = petsFolder:FindFirstChild(trueName)
			if foundFolder then
				table.insert(sorted, {PetId = petId, BoostValue = foundFolder.SpeedBoost.Value})
			end
		end
	end
	table.sort(sorted, function(a, b)
		return a.BoostValue > b.BoostValue
	end)
	return sorted
end
function library.getMaxPets(player: Player)
	if marketPlaceService:UserOwnsGamePassAsync(player.UserId, 1329957565) then
		return 5
	end
	return 3
end

return library

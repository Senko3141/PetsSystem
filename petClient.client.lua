-- PetClient
--[[
	Handles replicating pets from server to client
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local assets = replicatedStorage:WaitForChild("Assets")
local petModels = assets.PetModels

local localPlayer = Players.LocalPlayer
local petReplicationFolder = workspace:WaitForChild("Map"):WaitForChild("Game"):WaitForChild("PlayerPets")

local serverFolder = petReplicationFolder.Server
local clientFolder = petReplicationFolder.Client

local Controller = {}

function Controller.createPetModel(owner: string, petId: string, index: number)
	local ownerPlayer = Players:FindFirstChild(owner)
	if ownerPlayer then
		local trueName = petId:split("/")[1]
		local foundModel = petModels:FindFirstChild(trueName)

		if foundModel then
			local petInstance: Model = foundModel:Clone()
			petInstance:SetAttribute("Owner", ownerPlayer.Name)
			petInstance:SetAttribute("Index", index)
			petInstance:PivotTo(CFrame.new(0,0,0))
			petInstance.Name = petId
			for _,v in petInstance:GetDescendants() do
				local s,e = pcall(function()
					local t = v.CollisionGroup
				end)
				if s then
					v.CollisionGroup = "NoCollide"
					v.CanCollide = false
				end
			end

			task.spawn(function()
				task.wait()
				petInstance.HumanoidRootPart.Anchored = true
				local animClone = script.Animations:Clone()
				animClone.Parent = petInstance
				local required = require(animClone)
				
				--
				required["Idle"] = petInstance.Humanoid:LoadAnimation(petInstance.AnimateScript.idle.Animation1)
				required["Walk"] = petInstance.Humanoid:LoadAnimation(petInstance.AnimateScript.walk.WalkAnim)
				required["Jump"] = petInstance.Humanoid:LoadAnimation(petInstance.AnimateScript.jump.JumpAnim)
				--
			end)

			petInstance.Parent = clientFolder
		end
	end
end
function Controller.removePetModel(petId: string)
	local found = clientFolder:FindFirstChild(petId)
	if found then
		found:Destroy()
	end
end
function Controller.init()

	local connections = {}

	-- Pet Is Changed
	local function petChanged(stringValue: StringValue, oldValue: string)
		Controller.removePetModel(oldValue)
		Controller.createPetModel(stringValue.Parent.Name, stringValue.Value, tonumber(stringValue.Name))
	end
	-- Pet Is Added to MainFolder
	local function petAdded(stringValue: StringValue?)
		if stringValue:IsA("StringValue") then
			local petId = stringValue.Value
			local currValue = stringValue.Value
			connections[stringValue] = stringValue.Changed:Connect(function()
				-- Pet Changed
				task.spawn(petChanged, stringValue, currValue)
				currValue = stringValue.Value
			end)
			Controller.createPetModel(stringValue.Parent.Name, currValue, tonumber(stringValue.Name))
		end
	end
	-- Pet Is Removed From MainFolder
	local function petRemoved(stringValue: StringValue?)
		if stringValue:IsA("StringValue") then
			local petId = stringValue.Value

			Controller.removePetModel(petId)
			--print(petId, stringValue, "Removed")

			if connections[stringValue] then
				connections[stringValue]:Disconnect()
				connections[stringValue] = nil
			end
		end
	end

	local function childAdded(child: Instance)
		if child:IsA("Folder") then
			connections[child] = {}
			table.insert(connections[child], child.ChildAdded:Connect(petAdded))
			table.insert(connections[child], child.ChildRemoved:Connect(petRemoved))
			for _,v in child:GetChildren() do
				petAdded(v)
			end
		end
	end
	local function childRemoved(child: Instance)
		if child:IsA("Folder") then
			local conns = connections[child]
			if conns then
				for index,_ in conns do
					conns[index]:Disconnect()
					conns[index] = nil
				end
			end
			-- Destroying Pets
			for _,v in clientFolder:GetChildren() do
				if v:GetAttribute("Owner") == child.Name then
					v:Destroy()
				end
			end
			--
		end
	end

	serverFolder.ChildAdded:Connect(childAdded)
	serverFolder.ChildRemoved:Connect(childRemoved)

	for _, v in serverFolder:GetChildren() do
		childAdded(v)
	end

	-- Handling Pet Tracing
	task.spawn(function()
		local function getPyramidRowCol(index)
			local row = 1
			local cumulative = 1
			while index > cumulative do
				row = row + 1
				cumulative = cumulative + row
			end
			local rowStart = cumulative - row + 1
			local col = index - rowStart + 1
			return row, col
		end
		local function getPetOffset(index)
			local row, col = getPyramidRowCol(index)
			local spread = 3 -- studs between pets
			local zOffset = row * 3 -- each row 3 studs behind

			local rowWidth = (row - 1) * spread
			local x = (col - 1) * spread - rowWidth / 2

			local y = 2 -- fixed height above ground (tweak as needed)
			return Vector3.new(x, y, -zOffset)
		end

		local LERP_ALPHA = 0.15 -- Smoothness factor, tweak as needed

		RunService.RenderStepped:Connect(function(dt)
			-- Group pets by owner for formation
			local petsByOwner = {}
			for _, pet in ipairs(clientFolder:GetChildren()) do
				local owner = pet:GetAttribute("Owner")
				if owner then
					petsByOwner[owner] = petsByOwner[owner] or {}
					table.insert(petsByOwner[owner], pet)
				end
			end

			for owner, petList in pairs(petsByOwner) do
				local ownerPlayer = Players:FindFirstChild(owner)
				local character = ownerPlayer and ownerPlayer.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")

				if rootPart then
					-- Sort pets by their index
					table.sort(petList, function(a, b)
						return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
					end)
					for i, pet in ipairs(petList) do
						local humanoid = pet:FindFirstChildWhichIsA("Humanoid")
						local hipHeight = humanoid and humanoid.HipHeight or 0

						local ownerHumanoid: Humanoid = character:FindFirstChild("Humanoid")
						if ownerHumanoid then
							local animationsModule = pet:FindFirstChild("Animations")
							if animationsModule then
								animationsModule = require(animationsModule)
								if ownerHumanoid.MoveDirection.Magnitude > 0 then
									if animationsModule.Idle.IsPlaying then
										animationsModule.Idle:Stop(.1)
									end
									if not animationsModule.Walk.IsPlaying then
										animationsModule.Walk:Play()
									end
								else
									if animationsModule.Walk.IsPlaying then
										animationsModule.Walk:Stop(.1)
									end
									if not animationsModule.Idle.IsPlaying then
										animationsModule.Idle:Play()
									end
								end
							end
						end
						local offset = getPetOffset(i)
						-- Add hipHeight to Y
						offset = Vector3.new(offset.X, offset.Y + hipHeight/8 , offset.Z)

						local targetCF = rootPart.CFrame * CFrame.new(-offset)
						-- Lerp position
						local petRoot = pet.PrimaryPart or pet:FindFirstChild("HumanoidRootPart") or pet:FindFirstChildWhichIsA("BasePart")
						if petRoot then
							local currentCF = pet:GetPrimaryPartCFrame()
							local lerped = currentCF.Position:Lerp(targetCF.Position, LERP_ALPHA)
							pet:SetPrimaryPartCFrame(CFrame.new(lerped) * targetCF.Rotation)
						end
					end
				else
					-- Owner not found, reset pets
					for _, pet in ipairs(petList) do
						pet:SetPrimaryPartCFrame(CFrame.new(0,0,0))
					end
				end
			end
		end)
	end)
end

return Controller

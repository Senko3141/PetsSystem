local players = game:GetService("Players")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local httpService = game:GetService("HttpService")

local remotes = replicatedStorage:WaitForChild("Remotes")
local assets = replicatedStorage:WaitForChild("Assets")
local modules = replicatedStorage:WaitForChild("Modules")

local localPlayer = players.LocalPlayer

local playerGui = localPlayer.PlayerGui
local mainGui = playerGui:WaitForChild("UI")
local petFrame = mainGui.Frames.Pets
local listFrame = petFrame.Background.Frame.List
local replicationFolder = workspace:FindFirstChild("Map"):WaitForChild("Game"):WaitForChild("PlayerPets")
local serverFolder = replicationFolder.Server
local utilFrame = petFrame.Background.Frame.Util

local petLibrary = require(modules.Shared.PetLib)

local Controller = {}

local selectedFrame = Instance.new("StringValue")
selectedFrame.Name = "SelectedFrame"
selectedFrame.Value = ""
selectedFrame.Parent = script

local function reorderFrames(orderType: string)
	if not orderType then
		-- Order By Equipped
		for _,v in listFrame:GetChildren() do
			if v:IsA("Frame") then
				if v.Equipped.Visible then
					v.LayoutOrder = 0
				else
					v.LayoutOrder = 1
				end
			end
		end
	end
end
function Controller.selectionChanged()
	-- Updating SelectedFrame
	for _,v in listFrame:GetChildren() do
		if v:IsA("Frame") then
			if selectedFrame.Value == v.Name then
				v.SelectedFrame.Visible = true
			else
				v.SelectedFrame.Visible = false
			end
		end
	end
	--
	if selectedFrame.Value == "" then
		petFrame.Background.Frame.Buttons.Main.Visible = true
		petFrame.Background.Frame.Buttons.Selected_Object.Visible = false
	else
		petFrame.Background.Frame.Buttons.Main.Visible = false
		petFrame.Background.Frame.Buttons.Selected_Object.Visible = true
		
		local isEquipped = false
		local foundFolder = serverFolder:FindFirstChild(localPlayer.Name)
		if foundFolder then
			for _,v in foundFolder:GetChildren() do
				if v.Value == selectedFrame.Value then
					-- Is Equipped
					isEquipped = true
					break
				end
			end
		end
		if isEquipped then
			petFrame.Background.Frame.Buttons.Selected_Object.Equip.Visible = false
			petFrame.Background.Frame.Buttons.Selected_Object.Unequip.Visible = true
		else
			petFrame.Background.Frame.Buttons.Selected_Object.Equip.Visible = true
			petFrame.Background.Frame.Buttons.Selected_Object.Unequip.Visible = false
		end
	end
end
function Controller.updateInventory(data: any)
	local action = data.Action
	
	if action == "UpdateAll" then
		local inventory = data.Inventory
		-- Claering Frames
		for _,v in listFrame:GetChildren() do
			if v:IsA("Frame") then
				v:Destroy()
			end
		end
		---
		for petId: string, serializedValue: string in inventory do
			local decoded = httpService:JSONDecode(serializedValue)
			Controller.updateInventory({Action = "NewPet", PetInfo = {ID = petId, Info = decoded}})
		end
	end
	if action == "NewPet" then
		local PetInfo = data.PetInfo		
		if PetInfo then
			local id: string = PetInfo.ID
			local decodedInfo: any = PetInfo.Info
			
			-- Updating Gui
			if not listFrame:FindFirstChild(id) then
				local clone = script.UnitTemplate:Clone()
				clone.Name = id
				clone.Frame.PetName.Text = id:split("/")[1]
				clone.Frame.Rarity.Text = "Common" -- Change Later
				
				-- No Viewports, Causes Unnecesssary Lag
				local dataFolder = modules.Shared.Pets:FindFirstChild(clone.Frame.PetName.Text)
				if dataFolder then
					clone.Frame.Icon.Avatar.Image = dataFolder.IconId.Image
				else
					clone.Frame.Icon.Avatar.Image = ""
				end
								
				-- Checking if Equipped
				local isEquipped = false
				local foundFolder = serverFolder:FindFirstChild(localPlayer.Name)
				if foundFolder then
					for _,v in foundFolder:GetChildren() do
						if v.Value == id then
							-- Is Equipped
							isEquipped = true
							break
						end
					end
				end
				clone.Equipped.Visible = isEquipped
				
				-- Handling Clicking
				clone.Frame.MouseButton1Click:Connect(function()
					if selectedFrame.Value == id then
						-- Deselect
						selectedFrame.Value = ""
					else
						selectedFrame.Value = id
					end
				end)
				clone.Frame.MouseEnter:Connect(function()
					clone.InfoFrame.Visible = true
					local infoDisplay = modules.Shared.Pets[clone.Frame.PetName.Text]["InfoDisplay"].Value
					clone.InfoFrame.Label.Text = infoDisplay
				end)
				clone.Frame.MouseLeave:Connect(function()
					clone.InfoFrame.Visible = false
					clone.InfoFrame.Label.Text = "-"
				end)
				---
				
				clone.Parent = listFrame
			end
		end
	end
	if action == "PetRemoved" then
		local petId: string = data.PetId
		local foundFrame = listFrame:FindFirstChild(petId)
		if foundFrame then
			foundFrame:Destroy()
		end
		if selectedFrame.Value == petId then
			selectedFrame.Value = ""
		end
	end
	if action == "PetUpdated" then
		local petId: string = data.PetId
		local foundFrame = listFrame:FindFirstChild(petId)
		if foundFrame then
			
			-- Checking if Equipped
			local isEquipped = false
			local foundFolder = serverFolder:FindFirstChild(localPlayer.Name)
			if foundFolder then
				for _,v in foundFolder:GetChildren() do
					if v.Value == petId then
						-- Is Equipped
						isEquipped = true
						break
					end
				end
			end
			foundFrame.Equipped.Visible = isEquipped
			
			-- Other Checks, Etc.
			
			--
		end
	end
	
	-- Reordering
	reorderFrames()
	
	-- Updating UtilFrame
	task.spawn(function()
		local equippedPets = 0
		local maxPets = petLibrary.getMaxPets(localPlayer)
		for _,v in listFrame:GetChildren() do
			if v:IsA("Frame") and v.Equipped.Visible then
				-- Change Value
				equippedPets += 1
			end
		end
		utilFrame.Equipped.Button.Value.Text = tostring(equippedPets).."/"..tostring(maxPets)
	end)
end
function Controller.init()
	local function characterAdded()
		
	end
	if localPlayer.Character then characterAdded() end
	localPlayer.CharacterAdded:Connect(characterAdded)
	
	remotes.PetsInventory.OnClientEvent:Connect(Controller.updateInventory)
	
	-- Loading Inventory Default
	repeat task.wait() until remotes.GetPlayerInventory:InvokeServer() ~= nil
	local playerInventory = remotes.GetPlayerInventory:InvokeServer()
	Controller.updateInventory({Action = "UpdateAll", Inventory = playerInventory})
	
	-- Updating Selection Changed
	Controller.selectionChanged()
	selectedFrame.Changed:Connect(Controller.selectionChanged)
	
	-- Handling PetFrame [Buttons]
	local buttonsFrame = petFrame.Background.Frame.Buttons
	buttonsFrame.Selected_Object.Cancel.Button.MouseButton1Click:Connect(function()
		-- Stop Selecting
		selectedFrame.Value = ""
	end)
	buttonsFrame.Selected_Object.Equip.Button.MouseButton1Click:Connect(function()
		-- Equip [selectedFrame.Value]
		remotes.PetsInventory:FireServer("Equip", selectedFrame.Value)
		selectedFrame.Value = ""
	end)
	buttonsFrame.Selected_Object.Unequip.Button.MouseButton1Click:Connect(function()
		-- Unequip [selectedFrame.Value]
		remotes.PetsInventory:FireServer("Unequip", selectedFrame.Value)
		selectedFrame.Value = ""
	end)
	buttonsFrame.Selected_Object.Delete.Button.MouseButton1Click:Connect(function()
		-- Delete [selectedFrame.Value]
		remotes.PetsInventory:FireServer("Delete", selectedFrame.Value)
		selectedFrame.Value = ""
	end)
	
	--
	buttonsFrame.Main.Best.Button.MouseButton1Click:Connect(function()
		-- Equip Best Pets
		remotes.PetsInventory:FireServer("EquipBest")
	end)
	buttonsFrame.Main.UnequipAll.Button.MouseButton1Click:Connect(function()
		-- Unequip All
		remotes.PetsInventory:FireServer("UnequipAll")
	end)
end

return Controller

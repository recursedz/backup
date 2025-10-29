local rawSettings = {
	TOGGLE = "K",
	TARGET_LIMB = "Head",
	LIMB_SIZE = 5,
	MOBILE_BUTTON = true,
	LIMB_TRANSPARENCY = 0.9,
	LIMB_CAN_COLLIDE = false,
	TEAM_CHECK = false,
	FORCEFIELD_CHECK = false,
	RESET_LIMB_ON_DEATH2 = false,
	USE_HIGHLIGHT = true,
	DEPTH_MODE = "Occluded",
	HIGHLIGHT_FILL_COLOR = Color3.fromRGB(0, 255, 0),
	HIGHLIGHT_FILL_TRANSPARENCY = 0.5,
	HIGHLIGHT_OUTLINE_COLOR = Color3.fromRGB(255, 255, 255),
	HIGHLIGHT_OUTLINE_TRANSPARENCY = 0,
	LISTEN_FOR_INPUT = true
}

getgenv().limbExtenderData = getgenv().limbExtenderData or {}
local limbExtenderData = getgenv().limbExtenderData
local limbExtender = nil

if limbExtenderData.running ~= nil then
	limbExtenderData.terminateOldProcess("FullKill")
end

local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")
local contentProvider = game:GetService("ContentProvider")

local localPlayer = players.LocalPlayer

limbExtenderData.running = limbExtenderData.running or false
limbExtenderData.CAU = limbExtenderData.CAU
	or loadstring(game:HttpGet('https://raw.githubusercontent.com/AAPVdev/scripts/refs/heads/main/ContextActionUtility.lua'))()
	--or require(script.Parent.ContextActionUtility)

limbExtenderData.playerTable = limbExtenderData.playerTable or {}
limbExtenderData.limbs = limbExtenderData.limbs or {}

local playerTable = limbExtenderData.playerTable
local limbs = limbExtenderData.limbs
local contextActionUtility = limbExtenderData.CAU

local function getPlayers(func, includeLocalPlayer)
	for _, player in ipairs(players:GetPlayers()) do
		if includeLocalPlayer or player ~= localPlayer then
			func(player)
		end
	end
end

local function restoreLimbProperties(limb)
	local limbProperties = limbs[limb]
	local highlightInstance = limb:FindFirstChild("LimbHighlight")

	if not limbProperties then
		return
	end

	if highlightInstance then
		highlightInstance:Destroy()
	end

	limbProperties.SizeChanged:Disconnect()
	
	limbs[limb] = nil

	limb.Size = limbProperties.Size
	limb.CanCollide = limbProperties.CanCollide
	limb.Transparency = limbProperties.Transparency
	limb.Massless = limbProperties.Massless
end

local function saveLimbProperties(limb)
	if limbs[limb] then
		restoreLimbProperties(limb)
	end

	limbs[limb] = {
		Size = limb.Size,
		Transparency = limb.Transparency,
		CanCollide = limb.CanCollide,
		Massless = limb.Massless
	}
end

local function modifyLimbProperties(limb)
	saveLimbProperties(limb)
	local newSize = Vector3.new(rawSettings.LIMB_SIZE, rawSettings.LIMB_SIZE, rawSettings.LIMB_SIZE)
	limb.Size = newSize
	
	limbs[limb].SizeChanged = limb:GetPropertyChangedSignal("Size"):Connect(function()
		if limb.Size ~= newSize then
			limb.Size = newSize
		end
	end)
	
	limb.Transparency = rawSettings.LIMB_TRANSPARENCY
	limb.CanCollide = rawSettings.LIMB_CAN_COLLIDE

	if rawSettings.TARGET_LIMB ~= "HumanoidRootPart" then
		limb.Massless = true
	end

	local highlightInstance = limb:FindFirstChildWhichIsA("Highlight") or Instance.new("Highlight", limb)
	highlightInstance.Name = "LimbHighlight"
	highlightInstance.DepthMode = Enum.HighlightDepthMode[rawSettings.DEPTH_MODE]
	highlightInstance.FillColor = rawSettings.HIGHLIGHT_FILL_COLOR
	highlightInstance.FillTransparency = rawSettings.HIGHLIGHT_FILL_TRANSPARENCY
	highlightInstance.OutlineColor = rawSettings.HIGHLIGHT_OUTLINE_COLOR
	highlightInstance.OutlineTransparency = rawSettings.HIGHLIGHT_OUTLINE_TRANSPARENCY
	highlightInstance.Enabled = rawSettings.USE_HIGHLIGHT
end

local function removePlayerData(player)
	local playerData = playerTable[player.Name]
	if playerData then
		for _, connection in pairs(playerData) do
			if typeof(connection) == "RBXScriptConnection" then
				connection:Disconnect()
			end
		end

		playerTable[player.Name] = nil
	end
end

local function terminate(specialProcess)
	for key, connection in pairs(getgenv().limbExtenderData) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
			limbExtenderData[key] = nil
		end
	end

	getPlayers(removePlayerData, false)

	for limb, _ in pairs(limbExtenderData.limbs) do
		restoreLimbProperties(limb)
	end

	if specialProcess == "FullKill" then
			contextActionUtility:UnbindAction("LimbExtenderToggle")
			script:Destroy()
	else
		if not rawSettings.LISTEN_FOR_INPUT then
				contextActionUtility:UnbindAction("LimbExtenderToggle")
			elseif rawSettings.MOBILE_BUTTON then
				contextActionUtility:SetTitle("LimbExtenderToggle", "On")
			end
		end 
end

local function initiate()
	terminate()
	if not limbExtenderData.running then return end
	local function setupPlayer(player)
		local function characterAdded(character)
			if character then
				local playerData = playerTable[player.Name]
				if playerData then
					playerData["teamChanged"] = player:GetPropertyChangedSignal("Team"):Once(function()
 						removePlayerData(player)
 						setupPlayer(player)
 					end)
					
					local humanoid = character:WaitForChild("Humanoid", 0.2)
					local targetLimb = character:WaitForChild(rawSettings.TARGET_LIMB, 0.2)
					if targetLimb and humanoid and humanoid.Health > 0 then
						if (rawSettings.TEAM_CHECK and (localPlayer.Team == nil or player.Team ~= localPlayer.Team)) or not rawSettings.TEAM_CHECK then
							modifyLimbProperties(targetLimb)
						end
	
						playerData["characterRemoving"] = player.CharacterRemoving:Once(function()
							restoreLimbProperties(targetLimb)
						end)
						
						local connection = rawSettings.RESET_LIMB_ON_DEATH2 and humanoid.HealthChanged or humanoid.Died
						playerData["OnDeath"] = connection:Connect(function(health)
							if health and health <= 0 then
								restoreLimbProperties(targetLimb)
							end
						end)
					end
				end
			end
		end

		playerTable[player.Name] = {}
		playerTable[player.Name]["characterAdded"] = player.CharacterAdded:Connect(characterAdded)

		characterAdded(player.Character)
	end
	
	getPlayers(setupPlayer, false)

	limbExtenderData.teamChanged = localPlayer:GetPropertyChangedSignal("Team"):Once(initiate)
	limbExtenderData.playerAdded = players.PlayerAdded:Connect(setupPlayer)
	limbExtenderData.playerRemoving = players.PlayerRemoving:Connect(removePlayerData)

	if rawSettings.MOBILE_BUTTON and rawSettings.LISTEN_FOR_INPUT then
		contextActionUtility:SetTitle("LimbExtenderToggle", "Off")
	end
end

function rawSettings.toggleState(state)
	local newState = (state == nil) and (not limbExtenderData.running) or state
	
	limbExtenderData.running = newState
	
	if newState then
	    initiate()
	else
	    terminate()
	end
end

limbExtender = setmetatable({}, {
__index = rawSettings,
__newindex = function(_, key, value)
	if rawSettings[key] ~= value then
		rawSettings[key] = value
		if limbExtenderData.running then
			initiate()
		end
	end
end
})		
if rawSettings.LISTEN_FOR_INPUT then
	contextActionUtility:BindAction(
		"LimbExtenderToggle",
		function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				rawSettings.toggleState()
			end
		end,
		rawSettings.MOBILE_BUTTON,
		Enum.KeyCode[rawSettings.TOGGLE]
	)
end
limbExtenderData.terminateOldProcess = terminate

if limbExtenderData.running then
	initiate()
elseif rawSettings.MOBILE_BUTTON and rawSettings.LISTEN_FOR_INPUT then
	contextActionUtility:SetTitle("LimbExtenderToggle", "On")
end

return limbExtender

ESX = nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end

	while not ESX.GetPlayerData().job do
		Citizen.Wait(10)
	end

	ESX.PlayerData = ESX.GetPlayerData()

	-- Update the door list
	ESX.TriggerServerCallback('esx_doorlock:getDoorState', function(doorState)
		for index,state in pairs(doorState) do
			Config.DoorList[index].locked = state
		end
	end)
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job) ESX.PlayerData.job = job end)

RegisterNetEvent('esx_doorlock:setDoorState')
AddEventHandler('esx_doorlock:setDoorState', function(index, state) Config.DoorList[index].locked = state end)

DrawText3D = function(coords, text, size,fov,camCoords)
	local distance = #(coords - camCoords)

	local scale = (size / distance) * 2
	scale = scale * fov

	SetTextScale(0.0, 0.55 * scale)
	SetTextFont(0)
	SetTextColour(255, 255, 255, 255)
	SetTextDropshadow(0, 0, 0, 0, 255)
	SetTextDropShadow()
	SetTextOutline()
	SetTextCentre(true)

	SetDrawOrigin(coords, 0)
	BeginTextCommandDisplayText('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayText(0.0, 0.0)
	ClearDrawOrigin()
end

Citizen.CreateThread(function()
	while true do
		local playerCoords = GetEntityCoords(PlayerPedId())

		for k,v in ipairs(Config.DoorList) do
			local genAuthorized = false
			if v.doors then
				for k2,v2 in ipairs(v.doors) do
					v.distanceToPlayer = #(playerCoords - v2.objCoords)
					if v.distanceToPlayer < 50 then
						genAuthorized = true
						if v2.object and DoesEntityExist(v2.object) then
							if v.locked and v2.objHeading and ESX.Math.Round(GetEntityHeading(v2.object)) ~= v2.objHeading then
								SetEntityHeading(v2.object, v2.objHeading)
							end
							FreezeEntityPosition(v2.object, v.locked)
						else
							v.distanceToPlayer = nil
							v2.object = GetClosestObjectOfType(v2.objCoords, 1.0, v2.objHash, false, false, false)
						end
					else
						break
					end
				end
			else
				v.distanceToPlayer = #(playerCoords - v.objCoords)
				if v.distanceToPlayer < 50 then
					genAuthorized = true
					if v.object and DoesEntityExist(v.object) then
						if v.locked and v.objHeading and ESX.Math.Round(GetEntityHeading(v.object)) ~= v.objHeading then
							SetEntityHeading(v.object, v.objHeading)
						end
						FreezeEntityPosition(v.object, v.locked)
					else
						v.distanceToPlayer = nil
						v.object = GetClosestObjectOfType(v.objCoords, 1.0, v.objHash, false, false, false)
					end
				end
			end
			if genAuthorized then
				v.isAuthorized = isAuthorized(v)
			end
		end
		Citizen.Wait(500)
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		local letSleep = true
		local camCoords = GetGameplayCamCoords()
		local fov = (1 / GetGameplayCamFov()) * 100

		for k,v in ipairs(Config.DoorList) do
			if v.distanceToPlayer and v.distanceToPlayer < 50 then
				letSleep = false
			end

			if v.distanceToPlayer and v.distanceToPlayer < v.maxDistance then
				local size, displayText = 1, _U('unlocked')

				if v.size then size = v.size end
				if v.locked then displayText = _U('locked') end
				if v.isAuthorized then displayText = _U('press_button', displayText) end

				DrawText3D(v.textCoords, displayText, size, fov, camCoords)

				if IsControlJustReleased(0, 38) then
					if v.isAuthorized then
						v.locked = not v.locked
						TriggerServerEvent('esx_doorlock:updateState', k, v.locked) -- broadcast new state of the door to everyone
					end
				end
			end
		end

		if letSleep then
			Citizen.Wait(500)
		end
	end
end)

function isAuthorized(door)
	if not ESX or not ESX.PlayerData.job then
		return false
	end

	for k,job in pairs(door.authorizedJobs) do
		if job == ESX.PlayerData.job.name then
			return true
		end
	end

	return false
end

-- Call radio filter: proximity and calls together.
-- A call ignores distance, so everyone in it sounds the same. With the filter on, call members
-- closer than `near` meters sound like their plain voice, members further than `far` meters
-- sound like a radio (the 'callRadio' submix). In between they keep what they had, so walking
-- around the edge doesn't flicker. Members we can't see (no ped: out of streaming range, another
-- routing bucket) count as far unless `unseenAsRadio` is false.
--
-- Off by default (setr voice_callRadioFilter 1), or switched at runtime with the
-- setCallRadioFilter export, which can also replace the target list (default: call members).

local filterEnabled = GetConvarInt('voice_callRadioFilter', 0) == 1
local nearDist = GetConvarInt('voice_callRadioNear', 20) + 0.0
local farDist = GetConvarInt('voice_callRadioFar', 25) + 0.0
local unseenAsRadio = GetConvarInt('voice_callRadioUnseen', 1) == 1
local tickRate = GetConvarInt('voice_callRadioRate', 300)
local customTargets = nil -- [serverId] = true, replaces callData as the target list when set
local onRadio = {}        -- [serverId] = true while they have the callRadio submix

function isCallRadioFilterActive()
	return filterEnabled
end

---@return boolean onRadio whether serverId is currently heard through the call radio filter
function isOnCallRadio(serverId)
	return onRadio[serverId] == true
end

exports('isOnCallRadio', isOnCallRadio)

local function targets()
	return customTargets or callData
end

-- Puts the right submix on a player after the filter changed its mind about them.
local function applySubmix(serverId)
	if GetConvarInt('voice_enableSubmix', 1) ~= 1 then return end
	-- talking on the radio: radio.lua owns their submix and restores it when they stop
	if radioData[serverId] == true then return end
	if onRadio[serverId] or filterEnabled or not callData[serverId] then
		-- restoreDefaultSubmix knows about the filter (main.lua)
		restoreDefaultSubmix(serverId)
	else
		MumbleSetSubmixForServerId(serverId, submixIndicies['call'])
	end
end

-- nil when we can't see them.
local function distanceTo(serverId, myCoords)
	local ply = GetPlayerFromServerId(serverId)
	if ply == -1 then return nil end
	local ped = GetPlayerPed(ply)
	if ped == 0 or not DoesEntityExist(ped) then return nil end
	return #(myCoords - GetEntityCoords(ped))
end

---@param force boolean reapply every target's submix even if our state didn't change
local function update(force)
	local tgts = targets()

	-- whoever isn't a target any more loses the filter
	for id in pairs(onRadio) do
		if not filterEnabled or not tgts[id] then
			onRadio[id] = nil
			applySubmix(id)
		end
	end
	if not filterEnabled then return end

	local myCoords = GetEntityCoords(PlayerPedId())
	for id in pairs(tgts) do
		if id ~= playerServerId then
			local d = distanceTo(id, myCoords)
			local was = onRadio[id] == true
			local radio = was
			if not d then
				radio = unseenAsRadio
			elseif d > farDist then
				radio = true
			elseif d < nearDist then
				radio = false
			end
			if force or radio ~= was then
				onRadio[id] = radio or nil
				applySubmix(id)
			end
		end
	end
end

CreateThread(function()
	while true do
		if filterEnabled then
			update(false)
			Wait(tickRate)
		else
			Wait(1000)
		end
	end
end)

--- exports setCallRadioFilter
--- Turns the call radio filter on or off and tunes it.
---@param enabled boolean
---@param opts table|nil { near = number, far = number, unseenAsRadio = boolean,
---       targets = { serverId, ... } } every field optional; targets replaces the call members
---       as the players to filter, pass an empty `opts` (or no targets) to go back to them.
exports('setCallRadioFilter', function(enabled, opts)
	type_check({ enabled, "boolean" }, { opts, "table", "nil" })
	opts = opts or {}
	if opts.near then nearDist = opts.near + 0.0 end
	if opts.far then farDist = opts.far + 0.0 end
	if opts.unseenAsRadio ~= nil then unseenAsRadio = opts.unseenAsRadio == true end
	if type(opts.targets) == 'table' then
		customTargets = {}
		for _, id in ipairs(opts.targets) do
			id = tonumber(id)
			if id then customTargets[id] = true end
		end
	else
		customTargets = nil
	end
	local wasEnabled = filterEnabled
	filterEnabled = enabled
	update(true)
	-- the call members' submix depends on whether the filter is on (call submix vs none)
	if enabled ~= wasEnabled then
		for id in pairs(callData) do
			if id ~= playerServerId and not onRadio[id] then applySubmix(id) end
		end
	end
end)

exports('getCallRadioFilter', function()
	return filterEnabled
end)

-- Call members changed: put the filter on whoever joined right away.
RegisterNetEvent('pma-voice:syncCallData', function()
	if filterEnabled then SetTimeout(0, function() update(true) end) end
end)
RegisterNetEvent('pma-voice:addPlayerToCall', function()
	if filterEnabled then SetTimeout(0, function() update(false) end) end
end)

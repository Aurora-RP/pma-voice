-- Voice HUD (ui/): our own mic and who is talking right now.
--   * Our mic: voice range, call, radio channel; lit while we talk, "Muted" while muted
--     (/muteply). Other resources can replace the text with the setUiStatus export.
--   * Talkers: everyone we hear who is talking: players in proximity range, call members
--     (relayed by the server, so they show at any distance or bucket), and radio talkers.
--     Muted players never show. Far call members (call radio filter) and radio talkers get a
--     RADIO tag.
-- Left side above the minimap; bottom right when the radar is hidden.
-- Hidden while the pause menu is open, or with the setUiHidden export.

local TICK = GetConvarInt('voice_uiRefreshRate', 200)
local uiEnabled = GetConvarInt('voice_enableUi', 1) == 1
local callTalkers = {} -- [serverId] = name, relayed by the server
local sent = false     -- what we last told the server about our own talking
local lastStart = 0    -- GetGameTimer() of our last "started talking" sent
local lastCall = 0
local hidden = false
local status = nil     -- { label, sub, micOff } from setUiStatus
local lastJson

RegisterNetEvent('pma-voice:setTalkingInCall', function(src, on, name)
	if type(src) ~= 'number' then return end
	callTalkers[src] = on == true and tostring(name or ('Player ' .. src)) or nil
end)

RegisterNetEvent('pma-voice:removePlayerFromCall', function(src)
	if src == playerServerId then
		callTalkers = {}
	else
		callTalkers[src] = nil
	end
end)

RegisterNetEvent('pma-voice:syncCallData', function()
	callTalkers = {}
end)

--- exports setUiHidden
--- Hides the voice HUD (e.g. while a custom menu is open).
---@param state boolean
exports('setUiHidden', function(state)
	type_check({ state, "boolean" })
	hidden = state
end)

--- exports setUiStatus
--- Replaces the text on our own mic. Call without arguments to go back to the default.
---@param label string|nil big text, e.g. "Lobby"
---@param sub string|nil small text under it
---@param micOff boolean|nil show the mic as off
exports('setUiStatus', function(label, sub, micOff)
	type_check({ label, "string", "nil" }, { sub, "string", "nil" }, { micOff, "boolean", "nil" })
	if label == nil and sub == nil and micOff == nil then
		status = nil
	else
		status = { label = label or '', sub = sub or '', micOff = micOff == true }
	end
end)

-- Mumble natives may hand back 1/0 instead of true/false, and 0 is truthy in Lua.
local function isTrue(v)
	return v == true or v == 1
end

local function selfTalking()
	local me = PlayerId()
	return isTrue(MumbleIsPlayerTalking(me)) or isTrue(NetworkIsPlayerTalking(me))
end

-- Tells the server when we start or stop talking, while we're in a call. A "started" waits out
-- voice_talkingInterval (the server would drop it), so a quick second word shows a moment later.
local function reportTalking(on, callChannel)
	if callChannel ~= lastCall then
		-- the server forgot our talking when we left the old call
		lastCall = callChannel
		sent = false
	end
	if callChannel == 0 or on == sent then return end
	local t = GetGameTimer()
	if on and t - lastStart < GetConvarInt('voice_talkingInterval', 250) then return end
	if on then lastStart = t end
	sent = on
	TriggerServerEvent('pma-voice:setTalkingInCall', on)
end

-- How far ply's voice carries: their own range (state bag), ours as a fallback.
local function hearingRange(serverId)
	local prox = Player(serverId).state.proximity
	local range = type(prox) == 'table' and tonumber(prox.distance) or proximity
	if GetConvar('voice_useNativeAudio', 'false') == 'true' then range = range * 3 end
	return range
end

local function radioTag(id)
	return radioData[id] == true or isOnCallRadio(id)
end

local function currentTalkers()
	local names = {}
	for id, name in pairs(callTalkers) do names[id] = name end

	-- radio talkers
	if getRadioChannel() > 0 and isRadioEnabled() then
		for id, on in pairs(radioData) do
			if on == true and id ~= playerServerId and not names[id] then
				local ply = GetPlayerFromServerId(id)
				names[id] = ply ~= -1 and GetPlayerName(ply) or ('Player ' .. id)
			end
		end
	end

	-- players we can see: in a call with us, or close enough to hear
	local me = PlayerId()
	local myCoords = GetEntityCoords(PlayerPedId())
	for _, ply in ipairs(GetActivePlayers()) do
		if ply ~= me and isTrue(NetworkIsPlayerTalking(ply)) then
			local id = GetPlayerServerId(ply)
			if not names[id] then
				local inRange = callData[id]
				if not inRange then
					local ped = GetPlayerPed(ply)
					inRange = #(myCoords - GetEntityCoords(ped)) <= hearingRange(id)
				end
				if inRange then names[id] = GetPlayerName(ply) end
			end
		end
	end

	local list = {}
	for id, name in pairs(names) do
		if not isPlayerMuted(id) then
			list[#list + 1] = { id = id, name = name, radio = radioTag(id) }
		end
	end
	table.sort(list, function(a, b) return a.id < b.id end)
	return list
end

local function selfStatus(callChannel)
	if status then return status.label, status.sub, status.micOff end
	if LocalPlayer.state.muted == true then return 'Muted', '', true end

	local prox = LocalPlayer.state.proximity
	local label = type(prox) == 'table' and prox.mode or 'Voice'
	local parts = {}
	if callChannel ~= 0 then parts[#parts + 1] = 'Call' end
	local radio = getRadioChannel()
	if radio > 0 and isRadioEnabled() then parts[#parts + 1] = ('Radio %s MHz'):format(radio) end
	if radioPressed then label = 'Radio' end
	return label, table.concat(parts, ' · '), false
end

CreateThread(function()
	if not uiEnabled then return end
	while true do
		local callChannel = LocalPlayer.state.callChannel or 0
		local talking = selfTalking()
		local label, sub, micOff = selfStatus(callChannel)
		reportTalking(talking and not micOff, callChannel)

		local state = {
			action = 'state',
			visible = isInitialized and not hidden and not IsPauseMenuActive(),
			corner = IsRadarHidden(),
			label = label,
			sub = sub,
			micOff = micOff,
			talking = talking,
			usingRadio = radioPressed,
			talkers = isInitialized and currentTalkers() or {},
		}
		-- Only send what changed.
		local encoded = json.encode(state)
		if encoded ~= lastJson then
			lastJson = encoded
			sendUIMessage(state)
		end
		Wait(TICK)
	end
end)

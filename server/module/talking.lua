-- Talking relay for calls: a call member out of our streaming range (or in another routing
-- bucket) can't be seen talking on the client, so clients report their own talking and the
-- server passes it on to the rest of their call. Used by the UI's talker list.
--
-- Only changes count, and a new "started" at most every voice_talkingInterval ms, so nobody can
-- flood a big call. Muted players (/muteply) are never shown talking.

local interval = GetConvarInt('voice_talkingInterval', 250)
local talking = {}  -- [source] = true while they talk (as their client reported it)
local lastTalk = {} -- [source] = GetGameTimer() of their last accepted "started talking"

local function relay(source, callChannel, on)
	local members = callData[callChannel]
	if not members then return end
	local name = GetPlayerName(source) or ('Player ' .. source)
	for player, _ in pairs(members) do
		if player ~= source then
			TriggerClientEvent('pma-voice:setTalkingInCall', player, source, on, name)
		end
	end
end

--- Tells the rest of the call source stopped talking. Called before they leave a call, so it
--- doesn't show them talking forever.
---@param source number
---@param callChannel number the call they're leaving
function stopTalkingInCall(source, callChannel)
	if not talking[source] then return end
	talking[source] = nil
	relay(source, callChannel, false)
end

RegisterNetEvent('pma-voice:setTalkingInCall', function(on)
	local source = source
	if type(on) ~= 'boolean' or (talking[source] == true) == on then return end
	local plyVoice = voiceData[source]
	local callChannel = plyVoice and plyVoice.call or 0
	if callChannel == 0 then return end
	if on then
		local t = GetGameTimer()
		if lastTalk[source] and t - lastTalk[source] < interval then return end
		if Player(source).state.muted == true then return end
		lastTalk[source] = t
		talking[source] = true
	else
		talking[source] = nil
	end
	relay(source, callChannel, on)
end)

AddEventHandler('playerDropped', function()
	-- removePlayerFromCall already told the call
	talking[source] = nil
	lastTalk[source] = nil
end)

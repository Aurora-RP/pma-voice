## setCallRadioFilter

Proximity and calls together: call members near you sound like their plain voice, call members
far away sound like a radio. In between `near` and `far` they keep what they had, so walking
around the edge doesn't flicker. While the filter is on it replaces the call submix.

Starts as `voice_callRadioFilter` (default off).

Args:

| Argument | Type    | Description |
|----------|---------|-------------|
| enabled  | boolean | Turn the filter on or off |
| opts     | table?  | `near` (number, meters), `far` (number, meters), `unseenAsRadio` (boolean: call members the client can't see count as far), `targets` (array of server ids to filter instead of the call members; leave it out to go back to the call members) |

```lua
-- crew call: far crewmates and ones out of streaming range sound like a radio
exports['pma-voice']:setCallRadioFilter(true, { unseenAsRadio = true })

-- big lobby call: only filter these players, and only when we can see them
exports['pma-voice']:setCallRadioFilter(true, { targets = { 3, 7 }, unseenAsRadio = false })

exports['pma-voice']:setCallRadioFilter(false)
```

Getters: `exports['pma-voice']:getCallRadioFilter()` returns whether it's on,
`exports['pma-voice']:isOnCallRadio(serverId)` whether that player is heard through it right now.

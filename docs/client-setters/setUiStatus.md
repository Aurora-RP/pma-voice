## setUiStatus

Replaces the text on your own mic in the voice UI (by default: voice range, plus call and radio
channel; "Muted" while muted). Call it without arguments to go back to the default.

| Argument | Type     | Description |
|----------|----------|-------------|
| label    | string?  | Big text |
| sub      | string?  | Small text under it |
| micOff   | boolean? | Show the mic as off |

```lua
exports['pma-voice']:setUiStatus('Lobby', 'Everyone can hear you')
exports['pma-voice']:setUiStatus('Mic off', 'Join a crew to talk', true)
exports['pma-voice']:setUiStatus()
```

## setUiHidden

Hides the voice UI, e.g. while your own menu is open. It hides itself during the pause menu.

```lua
exports['pma-voice']:setUiHidden(true)
```

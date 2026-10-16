#!/bin/bash
# picker-guard — last line of defence against screen-capture overlays.
#
# A stuck or chattering key can fire a capture bind repeatedly. Each spawn
# (slurp / hyprpicker / satty) grabs the pointer and freezes a copy of the
# screen; stack enough of them and the display is solid white with no way out
# except a TTY. This runs for the first 90s of a session:
#   1. clears overlays left over from a previous session
#   2. wipes any burst of capture overlays. A normal region pick now runs a
#      deliberate stack of up to 4 slurp instances (slurp-tap keeps a
#      pre-mapped stack so tap-and-drag works; shot also kills strays on
#      every start), so the tripwire sits at 5: still far below anything
#      that could whiten the screen, above anything intentional.
# Exits on its own so it costs nothing after login.
pkill -x slurp 2>/dev/null
pkill -x hyprpicker 2>/dev/null
pkill -x satty 2>/dev/null

for _ in $(seq 1 90); do
    sleep 1
    # pgrep takes a single pattern, so count each overlay type and sum them
    count=$( (pgrep -x slurp; pgrep -x hyprpicker; pgrep -x satty) 2>/dev/null | wc -l )
    if [ "$count" -gt 5 ]; then
        pkill -x slurp 2>/dev/null
        pkill -x hyprpicker 2>/dev/null
        pkill -x satty 2>/dev/null
    fi
done

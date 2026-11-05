#!/usr/bin/env bash
# Example NOTIFY_CMD for /etc/usb-cloner/cloner.conf. Copy it to
# /etc/usb-cloner/notify.sh, make it executable, keep the backends you have.
#
# Called as:  notify.sh <state> <text>
#   running    write phase started
#   verifying  read-back started
#   pass       every drive passed
#   fail       at least one drive failed (text says how many)
#   idle       drives removed, ready for the next batch
#
# It runs in the background and its output is discarded, so it may be slow
# but must never prompt.

state=$1
text=${2:-}

# --- USB light: blink(1) (ThingM), needs blink1-tool installed ---------------
# apt-get install blink1-tool   (or build from https://github.com/todbot/blink1-tool)
if command -v blink1-tool >/dev/null; then
    case $state in
        running)   blink1-tool -q --rgb 0,0,255 --blink 0 ;;      # solid blue
        verifying) blink1-tool -q --rgb 255,120,0 ;;              # amber
        pass)      blink1-tool -q --rgb 0,255,0 ;;                # green
        fail)      blink1-tool -q --rgb 255,0,0 --blink 20 ;;     # red, blinking
        idle)      blink1-tool -q --off ;;
    esac
fi

# --- Push message: ntfy (self-hosted or ntfy.sh), needs curl -----------------
# Subscribe to the topic in the ntfy phone app.
NTFY_URL=""          # e.g. https://ntfy.sh/powerhouse-cloner  (leave empty to disable)
if [[ -n $NTFY_URL ]] && command -v curl >/dev/null; then
    case $state in
        pass) curl -fsS -H "Title: USB cloner: PASS" -H "Tags: white_check_mark" -d "$text" "$NTFY_URL" ;;
        fail) curl -fsS -H "Title: USB cloner: FAIL" -H "Tags: x" -H "Priority: high" -d "$text" "$NTFY_URL" ;;
    esac
fi

# --- Beep on the box's own speaker, needs alsa-utils ------------------------
if command -v speaker-test >/dev/null; then
    beep() { timeout "$1" speaker-test -t sine -f "$2" -l 1 >/dev/null 2>&1 || true; }
    case $state in
        pass) beep 0.3 880; sleep 0.1; beep 0.3 1320 ;;
        fail) beep 0.6 220; sleep 0.2; beep 0.6 220; sleep 0.2; beep 0.6 220 ;;
    esac
fi

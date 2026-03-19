#
# AI-powered shell helpers using GitHub Copilot CLI
#

_ai_spinner() {
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    tput civis  # hide cursor
    while true; do
        printf '\r  \e[36m%s\e[0m \e[2mThinking...\e[0m' "${frames[$((i % ${#frames[@]} + 1))]}"
        i=$((i + 1))
        sleep 0.08
    done
}

_ai_spinner_stop() {
    kill "$1" 2>/dev/null
    wait "$1" 2>/dev/null
    printf '\r\033[K'  # clear spinner line
    tput cnorm  # restore cursor
}

function ghcs() {
    if [[ -z "$*" ]]; then
        echo "Usage: ghcs <natural language description>"
        echo "Example: ghcs 'find all .ts files modified in the last 24 hours'"
        return 1
    fi

    if ! command -v copilot >/dev/null 2>&1; then
        echo "Error: copilot CLI not found" >&2
        return 1
    fi

    local prompt="Suggest a single shell command that fulfills the following request."
    prompt+="\nOutput ONLY a fenced code block with the command, nothing else. No explanation."
    prompt+="\nSystem: {\"platform\": \"$(uname -s)\", \"architecture\": \"$(uname -m)\"}"
    prompt+="\nRequest: $*"

    setopt local_options no_monitor  # suppress job control messages from background spinner

    _ai_spinner &
    local spinner_pid=$!
    local response
    if ! response=$(copilot --model="claude-haiku-4.5" -s -p "$prompt" 2>&1); then
        _ai_spinner_stop $spinner_pid
        echo "Error: copilot command failed" >&2
        echo "$response" >&2
        return 1
    fi
    _ai_spinner_stop $spinner_pid

    # Extract command from markdown code block (```bash ... ``` or ``` ... ```)
    local cmd
    cmd=$(echo "$response" | awk '/^```/{if(f){exit}f=1;next}f{print}')

    if [[ -z "$cmd" ]]; then
        echo "Could not extract a command from the response:" >&2
        echo "$response" >&2
        return 1
    fi

    echo ""
    echo "  \e[1;36m$cmd\e[0m"
    echo ""
    echo "  \e[2m[c]\e[0m Copy to clipboard"
    echo "  \e[2m[e]\e[0m Execute \e[33m(review carefully!)\e[0m"
    echo "  \e[2m[q]\e[0m Cancel"
    echo ""

    local choice
    read -sk 1 "choice?"

    case "$choice" in
        c)
            echo -n "$cmd" | pbcopy
            echo "Copied to clipboard."
            ;;
        e)
            # Add to shell history so it shows up in arrow-up recall
            print -s "$cmd"
            echo "\e[2mExecuting: $cmd\e[0m"
            echo ""
            eval "$cmd"
            ;;
        *)
            echo "Cancelled."
            ;;
    esac
}

function ghce() {
    if [[ -z "$*" ]]; then
        echo "Usage: ghce <command>"
        echo "Example: ghce 'du -sh .'"
        return 1
    fi

    if ! command -v copilot >/dev/null 2>&1; then
        echo "Error: copilot CLI not found" >&2
        return 1
    fi

    local prompt="Explain the following shell command in plain English. Be concise but thorough."
    prompt+="\nBreak down each flag and argument."
    prompt+="\nCommand: $*"

    setopt local_options no_monitor  # suppress job control messages from background spinner

    _ai_spinner &
    local spinner_pid=$!
    local response
    if ! response=$(copilot --model="claude-haiku-4.5" -s -p "$prompt" 2>&1); then
        _ai_spinner_stop $spinner_pid
        echo "Error: copilot command failed" >&2
        echo "$response" >&2
        return 1
    fi
    _ai_spinner_stop $spinner_pid

    echo ""
    echo "$response"
}

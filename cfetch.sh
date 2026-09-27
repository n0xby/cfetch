#!/bin/sh

C_RESET=$(tput sgr0 2>/dev/null | tr -d '\r\n')
C_BOLD=$(tput bold 2>/dev/null | tr -d '\r\n')
C_DIM=$(printf '\033[2m')
C_CYAN=$(tput setaf 6 2>/dev/null | tr -d '\r\n')
C_GREEN=$(tput setaf 2 2>/dev/null | tr -d '\r\n')
C_MAG=$(tput setaf 5 2>/dev/null | tr -d '\r\n')

SESSION_ID="$(date +%s)_$$"
TMP_ART="/tmp/cfetch_art_$SESSION_ID"
TMP_CONF="/tmp/cfetch_conf_$SESSION_ID"
TMP_TEXT="/tmp/cfetch_text_$SESSION_ID"
CONF_FILE="/tmp/cfetch_final_$SESSION_ID"

hex_to_ansi() {
    hex="$1"
    hex="${hex#\#}"
    case "$hex" in
        [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
        *) return 1 ;;
    esac
    r=$((0x$(printf "%s" "$hex" | cut -c1-2)))
    g=$((0x$(printf "%s" "$hex" | cut -c3-4)))
    b=$((0x$(printf "%s" "$hex" | cut -c5-6)))

    if [ "$r" = "$g" ] && [ "$g" = "$b" ]; then
        if [ "$r" -lt 8 ]; then idx=16
        elif [ "$r" -gt 248 ]; then idx=231
        else idx=$((232 + (r - 8) / 10))
        fi
    else
        ri=$(( (r * 5 + 127) / 255 ))
        gi=$(( (g * 5 + 127) / 255 ))
        bi=$(( (b * 5 + 127) / 255 ))
        idx=$((16 + 36 * ri + 6 * gi + bi))
    fi
    printf "\033[38;5;%dm" "$idx"
}

if [ "$1" = "--display" ] && [ -f "$2" ]; then
    . "$2"

    printf '\033[2J\033[3J\033[H'

    {
        printf "__TITLE__ %s@%s\n" "$USER_NAME" "$HOST_NAME"
        printf "__SEPARATOR__\n"
        while IFS= read -r line; do
            printf "%s\n" "$line"
        done < "$TMP_CONF"
        printf "\n"
        printf "__PALETTE1__\n"
        printf "__PALETTE2__\n"
    } > "$TMP_TEXT"

    stty sane 2>/dev/null
    tput cnorm 2>/dev/null

    ART_WIDTH=$(awk '
        function width(s,    i,c,n) {
            n=0
            for (i=1; i<=length(s); i++) {
                c=substr(s,i,1)
                if (c=="\t")
                    n += 8 - (n % 8)
                else
                    n++
            }
            return n
        }
        BEGIN { m=0 }
        {
            w=width($0)
            if (w>m) m=w
        }
        END { print m+0 }
    ' "$TMP_ART")
    PANEL_COL=$((POS_X + ART_WIDTH + 5))

    printf "%s\n\n" "$START_PROMPT"

    awk -v pos_x="$POS_X" -v pos_y="$POS_Y" \
        -v panel_col="$PANEL_COL" \
        -v c_art="$C_ART" -v c_key="$C_KEY" -v c_val="$C_VAL" \
        -v c_reset="$C_RESET" -v c_bold="$C_BOLD" \
        '
        FNR==NR { art[FNR] = $0; art_n = FNR; next }
        { text[FNR] = $0; text_n = FNR }
        END {
            max_rows = (art_n > text_n) ? art_n : text_n

            for (i = 1; i <= max_rows; i++) {
                if (i <= art_n) {
                    av = ""
                    for (j = 0; j < pos_x; j++)
                        av = av " "
                    av = av art[i]
                    printf "%s%s%s", c_art, av, c_reset
                }

                printf "\033[%dG", panel_col

                if (i <= text_n) {
                    line = text[i]

                    if (line == "__PALETTE1__") {
                        printf "\033[48;5;236m   \033[48;5;167m   \033[48;5;107m   \033[48;5;179m   \033[48;5;68m   \033[48;5;133m   \033[48;5;73m   \033[48;5;250m   \033[0m"
                    } else if (line == "__PALETTE2__") {
                        printf "\033[48;5;244m   \033[48;5;203m   \033[48;5;113m   \033[48;5;221m   \033[48;5;74m   \033[48;5;176m   \033[48;5;80m   \033[48;5;255m   \033[0m"
                    } else if (substr(line, 1, 9) == "__TITLE__") {
                        title = substr(line, 11)
                        title_len = length(title)
                        printf "%s%s%s", c_bold, title, c_reset
                    } else if (line == "__SEPARATOR__") {
                        if (title_len == 0)
                            title_len = 17
                        for (k = 0; k < title_len; k++)
                            printf "-"
                    } else {
                        idx = index(line, ": ")
                        if (idx > 0) {
                            key = substr(line, 1, idx - 1)
                            val = substr(line, idx + 2)
                            printf "%s%s%s: %s%s%s", c_key, key, c_reset, c_val, val, c_reset
                        } else {
                            printf "%s", line
                        }
                    }
                }

                printf "\n"
            }
        }
        ' "$TMP_ART" "$TMP_TEXT"

    printf "\n%s" "$END_PROMPT"

    rm -f "$TMP_ART" "$TMP_CONF" "$TMP_TEXT" "$CONF_FILE"

    tput civis
    exec sleep 999999
fi

cleanup_cfg() {
    stty sane 2>/dev/null
    tput cnorm 2>/dev/null
}
trap cleanup_cfg EXIT INT TERM

select_color() {
    _prompt="$1"
    _default="$2"

    {
        printf "\n  %s→%s %s\n\n" "$C_GREEN" "$C_RESET" "$_prompt"
        printf "    %s1%s  \033[38;5;203m███%s  red       %s#E05C5C%s\n" "$C_DIM" "$C_RESET" "$C_RESET" "$C_DIM" "$C_RESET"
        printf "    %s2%s  \033[38;5;107m███%s  green     %s#5CAF5C%s\n" "$C_DIM" "$C_RESET" "$C_RESET" "$C_DIM" "$C_RESET"
        printf "    %s3%s  \033[38;5;179m███%s  yellow    %s#C9A227%s\n" "$C_DIM" "$C_RESET" "$C_RESET" "$C_DIM" "$C_RESET"
        printf "    %s4%s  \033[38;5;68m███%s  blue      %s#5C87D7%s\n" "$C_DIM" "$C_RESET" "$C_RESET" "$C_DIM" "$C_RESET"
        printf "    %s5%s  \033[38;5;133m███%s  magenta   %s#B05CB0%s\n" "$C_DIM" "$C_RESET" "$C_RESET" "$C_DIM" "$C_RESET"
        printf "    %s6%s  \033[38;5;73m███%s  cyan      %s#5CB0B0%s\n" "$C_DIM" "$C_RESET" "$C_RESET" "$C_DIM" "$C_RESET"
        printf "    %s7%s  \033[38;5;250m███%s  white     %s#C8C8C8%s\n" "$C_DIM" "$C_RESET" "$C_RESET" "$C_DIM" "$C_RESET"
        printf "    %s8%s  \033[38;5;245m███%s  gray      %s#8A8A8A%s\n" "$C_DIM" "$C_RESET" "$C_RESET" "$C_DIM" "$C_RESET"
        printf "    %s9%s  \033[38;5;214m███%s  custom hex  %s(e.g. #FF8800)%s\n" "$C_DIM" "$C_RESET" "$C_RESET" "$C_DIM" "$C_RESET"
        printf "\n    %schoice%s [%s]: " "$C_DIM" "$C_RESET" "$_default"
    } >&2

    read -r _choice

    case "$_choice" in
        1) _color='\033[38;5;203m' ;;
        2) _color='\033[38;5;107m' ;;
        3) _color='\033[38;5;179m' ;;
        4) _color='\033[38;5;68m'  ;;
        5) _color='\033[38;5;133m' ;;
        6) _color='\033[38;5;73m'  ;;
        7) _color='\033[38;5;250m' ;;
        8) _color='\033[38;5;245m' ;;
        9)
            printf "    %shex (e.g. #FF8800):%s " "$C_DIM" "$C_RESET" >&2
            read -r _hex
            _color=$(hex_to_ansi "$_hex")
            if [ -z "$_color" ]; then
                printf "    %s⚠ bad hex, using default color%s\n" "$C_DIM" "$C_RESET" >&2
                _color=$(tput setaf "$_default")
            fi
            ;;
        *) _color=$(tput setaf "$_default") ;;
    esac

    printf "%s" "$_color" | tr -d '\r\n'
}

print_section() {
    printf "\n%s▸%s %s%s%s\n" "$C_CYAN" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"
}

clear
printf "\n"
printf "  %s%s%s\n" "$C_BOLD" "$C_MAG" "$C_RESET"
printf "  %s%s%s   %scustom fetch by github.com/n0xby%s         %s%s%s\n" \
    "$C_BOLD" "$C_MAG" "$C_RESET" "$C_BOLD" "$C_RESET" "$C_MAG" "$C_BOLD" "$C_RESET"
printf "  %s%s%s\n" "$C_BOLD" "$C_MAG" "$C_RESET"

print_section "user"
printf "  %susername%s: " "$C_DIM" "$C_RESET"
read -r USER_NAME
printf "  %shostname%s: " "$C_DIM" "$C_RESET"
read -r HOST_NAME

print_section "prompt line"
printf "  %sstyle:%s\n" "$C_DIM" "$C_RESET"
printf "    %s1%s  macos   %s%s ~ %% %s\n" "$C_DIM" "$C_RESET" "${USER_NAME:-user}@${HOST_NAME:-host}" "$C_RESET"
printf "    %s2%s  linux   %s%s:~$ %s\n" "$C_DIM" "$C_RESET" "${USER_NAME:-user}@${HOST_NAME:-host}" "$C_RESET"
printf "  %schoice%s [1]: " "$C_DIM" "$C_RESET"
read -r PROMPT_STYLE

printf "  %scommand%s (what was 'typed', e.g. 'cfetch --bio'): " "$C_DIM" "$C_RESET"
read -r PROMPT_CMD

case "$PROMPT_STYLE" in
    2)
        START_PROMPT="${USER_NAME}@${HOST_NAME}:~\$ ${PROMPT_CMD}"
        END_PROMPT="${USER_NAME}@${HOST_NAME}:~\$ "
        ;;
    *)
        START_PROMPT="${USER_NAME}@${HOST_NAME} ~ % ${PROMPT_CMD}"
        END_PROMPT="${USER_NAME}@${HOST_NAME} ~ % "
        ;;
esac

print_section "info"
printf "  %sformat:%s Key: Value\n" "$C_DIM" "$C_RESET"
printf "  %sexample:%s age: 42\n" "$C_DIM" "$C_RESET"
printf "  %sempty line to finish.%s\n\n" "$C_DIM" "$C_RESET"

> "$TMP_CONF"
while true; do
    printf "  %s→%s " "$C_GREEN" "$C_RESET"
    read -r line
    [ -z "$line" ] && break
    printf "%s\n" "$line" >> "$TMP_CONF"
done

print_section "ascii art"
printf "  %sfile path%s: " "$C_DIM" "$C_RESET"
read -r ART_PATH

if [ ! -f "$ART_PATH" ]; then
    printf "\n  %s✗ file '%s' not found!%s\n" "$(tput setaf 1)" "$ART_PATH" "$C_RESET"
    exit 1
fi

tr -d '\r' < "$ART_PATH" | sed 's/[[:space:]]*$//' > "$TMP_ART.raw"

awk '
{
    line[NR] = $0
}
END {
    n = NR
    start = 0; end = 0; blank = 0
    for (i = 1; i <= n; i++) {
        is_blank = (line[i] ~ /^[[:space:]]*$/)
        if (!is_blank && start == 0) start = i
        if (start > 0 && !is_blank) { end = i; blank = 0 }
        else if (start > 0 && is_blank) {
            blank++
            if (blank >= 2) break
        }
    }
    if (start > 0) for (i = start; i <= end; i++) print line[i]
}
' "$TMP_ART.raw" > "$TMP_ART"

rm -f "$TMP_ART.raw"

if [ ! -s "$TMP_ART" ]; then
    printf "\n  %s✗ art file is empty after processing.%s\n" "$(tput setaf 1)" "$C_RESET"
    exit 1
fi

print_section "colors"
C_ART=$(select_color "color for ascii art" 4)
C_KEY=$(select_color "color for keys" 6)
C_VAL=$(select_color "color for values" 7)

COLS=$(tput cols)
ROWS=$(tput lines)
X=$((COLS / 8))
Y=0

tput civis
stty -icanon min 1 time 0 -echo

while true; do
    clear
    printf "left / right arrows to move  |  %senter%s to save\n" \
        "$(tput setaf 2)" "$C_RESET"

    awk -v x="$X" -v y="$Y" -v c="$C_ART" -v r="$C_RESET" '
        BEGIN { for(i=0;i<y;i++) print "" }
        { printf "%*s%s%s%s\n", x, "", c, $0, r }
    ' "$TMP_ART"

    key=$(dd bs=1 count=1 2>/dev/null)

    if [ "$key" = "$(printf '\033')" ]; then
        seq=$(dd bs=1 count=2 2>/dev/null)
        case "$seq" in
            "[C") X=$((X+1)) ;;
            "[D") X=$((X-1)) ;;
        esac
    elif [ -z "$key" ] || [ "$key" = "$(printf '\r')" ] || [ "$key" = "$(printf '\n')" ]; then
        break
    fi

    [ $X -lt 0 ] && X=0
    MAX_X=$((COLS - 25))
    [ $X -gt $MAX_X ] && X=$MAX_X
done

stty sane
tput cnorm

{
    printf "USER_NAME='%s'\n" "$USER_NAME"
    printf "HOST_NAME='%s'\n" "$HOST_NAME"
    printf "START_PROMPT='%s'\n" "$START_PROMPT"
    printf "END_PROMPT='%s'\n" "$END_PROMPT"
    printf "C_ART='%s'\n" "$C_ART"
    printf "C_KEY='%s'\n" "$C_KEY"
    printf "C_VAL='%s'\n" "$C_VAL"
    printf "C_RESET='%s'\n" "$C_RESET"
    printf "C_BOLD='%s'\n" "$C_BOLD"
    printf "POS_X=%d\n" "$X"
    printf "POS_Y=%d\n" "$Y"
    printf "TMP_ART='%s'\n" "$TMP_ART"
    printf "TMP_CONF='%s'\n" "$TMP_CONF"
} > "$CONF_FILE"

ART_WIDTH=$(awk 'BEGIN{m=0} {if(length>m)m=length} END{print m+0}' "$TMP_ART")
ART_HEIGHT=$(awk 'END{print NR+0}' "$TMP_ART")

MAX_DATA=$(awk -F: '
    {
        if (NF >= 2) {
            v = substr($0, length($1)+2)
            t = length($1) + 2 + length(v)
        } else { t = length($0) }
        if (t > m) m = t
    }
    END { print m+0 }
' "$TMP_CONF")
[ "$MAX_DATA" -lt 18 ] && MAX_DATA=18
[ "$MAX_DATA" -lt 24 ] && MAX_DATA=24

PROMPT_LEN=${#START_PROMPT}

NEED_COLS=$((X + ART_WIDTH + 4 + MAX_DATA + 2))
[ "$NEED_COLS" -lt $((PROMPT_LEN + 4)) ] && NEED_COLS=$((PROMPT_LEN + 4))

NEED_ROWS=$((Y + ART_HEIGHT + 6))
[ "$NEED_COLS" -lt 60 ] && NEED_COLS=60
[ "$NEED_ROWS" -lt 20 ] && NEED_ROWS=20

SCRIPT_PATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"
[ -f "$SCRIPT_PATH" ] || SCRIPT_PATH="$0"

if [ "$(uname)" = "Darwin" ]; then
    W_PX=$((NEED_COLS * 7 + 30))
    H_PX=$((NEED_ROWS * 17 + 55))

    osascript >/dev/null 2>&1 <<EOF
tell application "Terminal"
    do script "clear; sh '$SCRIPT_PATH' --display '$CONF_FILE'"
    activate
    delay 0.4
    set bounds of front window to {60, 60, 60 + $W_PX, 60 + $H_PX}
end tell
EOF
    exit 0
else
    if command -v gnome-terminal >/dev/null 2>&1; then
        gnome-terminal --geometry=${NEED_COLS}x${NEED_ROWS} -- sh "$SCRIPT_PATH" --display "$CONF_FILE" &
        exit 0
    elif command -v konsole >/dev/null 2>&1; then
        konsole --geometry ${NEED_COLS}x${NEED_ROWS} -e sh "$SCRIPT_PATH" --display "$CONF_FILE" &
        exit 0
    elif command -v xfce4-terminal >/dev/null 2>&1; then
        xfce4-terminal --geometry=${NEED_COLS}x${NEED_ROWS} -e "sh $SCRIPT_PATH --display $CONF_FILE" &
        exit 0
    elif command -v xterm >/dev/null 2>&1; then
        xterm -geometry ${NEED_COLS}x${NEED_ROWS} -e sh "$SCRIPT_PATH" --display "$CONF_FILE" &
        exit 0
    else
        sh "$SCRIPT_PATH" --display "$CONF_FILE"
    fi
fi

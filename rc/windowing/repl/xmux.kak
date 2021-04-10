declare-option -docstring "xmux_keep_status" bool xmux_keep_status
declare-option -docstring "xmux_keep_prefix" bool xmux_keep_prefix
declare-option -docstring "xmux_use_public_tmux_socket" bool xmux_use_public_tmux_socket
declare-option -hidden str-list xmux_session_names

hook global ModuleLoaded connect %{
    require-module xmux
}

provide-module xmux %{

declare-option -hidden str xmux_socket
declare-option -hidden str xmux_socket_arg
declare-option -hidden str xmux_session
declare-option -hidden str xmux_conf
declare-option -hidden str xmux_session_root
declare-option -hidden str xmux_session_name
declare-option -hidden str xmux_last_send

define-command -params .. -docstring %{
    The session names to use when using xmux-repl
    when not specifying a specific name (less than
    two arguments)
} xmux-set-session-names %{
    set-option current xmux_session_names %arg{@}
}

define-command -hidden xmux-incrment-session-ext %{
    evaluate-commands %sh{
    }
}

define-command -hidden -params 0..1 xmux-repl-create %{
    connect-terminal tmux %opt{xmux_socket_arg} %opt{xmux_socket} -f %opt{xmux_conf} new-session -s %opt{xmux_session} %arg{@}
    evaluate-commands %sh{
        TMUX_SESSION_COUNT=0
        LOOP_COUNT=0
        while [ "$LOOP_COUNT" -lt 50 ] && [ "$TMUX_SESSION_COUNT" -lt 1 ]; do
            if tmux "$kak_opt_xmux_socket_arg" "$kak_opt_xmux_socket" list-sessions 2>&1 | grep "^$kak_opt_xmux_session" > /dev/null; then
                TMUX_SESSION_COUNT=1
            fi
            LOOP_COUNT=$((LOOP_COUNT + 1))
            sleep 0.1
        done
        if [ "$TMUX_SESSION_COUNT" -lt 1 ]; then
            echo "echo Could not re-attach to session"
            exit 1
        fi
        if [ "$kak_opt_xmux_keep_prefix" != "true" ]; then
            tmux "$kak_opt_xmux_socket_arg" "$kak_opt_xmux_socket" set-option -g prefix NONE
            tmux "$kak_opt_xmux_socket_arg" "$kak_opt_xmux_socket" set-option -g prefix2 NONE
        fi
        if [ "$kak_opt_xmux_keep_status" != "true" ]; then
            tmux "$kak_opt_xmux_socket_arg" "$kak_opt_xmux_socket" set status off
        fi
        echo 'define-command -override xmux-chars-'$kak_opt_xmux_session_name' -params 0..1 %{ xmux-send-to "'$kak_opt_xmux_session_name'" 0 %arg{@} }'
        echo 'define-command -override xmux-lines-'$kak_opt_xmux_session_name' -params 0..1 %{ xmux-send-to "'$kak_opt_xmux_session_name'" 1 %arg{@} }'
        echo 'define-command -override xmux-chars -params 0..1 %{ xmux-send-to "'$kak_opt_xmux_session_name'" 0 %arg{@} }'
        echo 'define-command -override xmux-lines -params 0..1 %{ xmux-send-to "'$kak_opt_xmux_session_name'" 1 %arg{@} }'
    }
}

define-command xmux-repl-select -hidden -params 0..1 %{
    evaluate-commands %sh{
        if [ "$#" -gt 0 ]; then
            echo "set-option current xmux_session_name \"$1\""
        else
            FIRST=1
            for X in $kak_opt_xmux_session_names; do
                if [ "$FIRST" -eq "1" ]; then
                    echo "set-option current xmux_session_name \"$X\""
                    echo "set-option -remove current xmux_session_names \"$X\""
                    FIRST=0
                fi
            done
            if [ "$FIRST" -eq "1" ]; then
                echo "set-option current xmux_session_name \"$(mktemp -u XXX)\""
            fi
        fi
    }
}

define-command xmux-repl-launch -hidden -params 0..1 %{
    evaluate-commands %sh{
        SOCKET="$kak_opt_xmux_socket"
        if [ -z "$kak_opt_xmux_socket" ]; then
            SOCKET="$(basename "$(mktemp -u -t 'kak-xmux-XXXXXXX')")"
        fi
        if [ ! -f ~/.xmux.conf ]; then
            touch "~/.xmux.conf"
        fi
        SESSION_ROOT="$kak_opt_xmux_session_root"
        if [ -z "$kak_opt_xmux_session_root" ]; then
            SESSION_ROOT="$SOCKET"
            # SESSION_ROOT="$(basename "$SOCKET")"
        fi
        echo "set-option current xmux_session_root \"$SESSION_ROOT\""
        if [ "$kak_opt_xmux_use_public_tmux_socket" = "true" ]; then
            echo "set-option current xmux_socket \"-q\""
            echo "set-option current xmux_socket_arg \"-q\""
        else
            echo "set-option current xmux_socket \"$SOCKET\""
            echo "set-option current xmux_socket_arg \"-L\""
        fi
        echo "set-option current xmux_session \"${SESSION_ROOT}_$kak_opt_xmux_session_name\""
        echo "set-option current xmux_conf \"$(realpath ~/.xmux.conf)\""
    }
    evaluate-commands %sh{
        EXISTS="$(tmux -L "$kak_opt_xmux_socket" list-session 2>/dev/null | awk -v name="$kak_opt_xmux_session" -F: 'BEGIN { FOUND=0 } { if ($1 == name) { FOUND=1 } } END { print FOUND }')"
        if [ "$EXISTS" -lt 1 ]; then
            echo "xmux-repl-create %arg{@}"
        fi
    }
}

define-command -docstring %{
    xmux-repl:          New REPL using $SHELL
    xmux-repl NAME:     New REPL named $NAME
    xmux-repl NAME CMD: New REPL named $NAME using $CMD
    xmux-repl "" CMD:   New REPL named $NAME
} \
    -params 0..2 \
    -shell-completion \
    xmux-repl %{
    evaluate-commands %sh{
        if [ "$#" -eq 0 ]; then
            echo "xmux-repl-select"
            echo "xmux-repl-launch"
            exit
        fi
        if [ "$#" -eq 1 ]; then
            echo "xmux-repl-select %arg{1}"
            echo "xmux-repl-launch"
            exit
        fi
        if [ "$1" = "" ]; then
            echo "xmux-repl-select"
            echo "xmux-repl-launch %arg{1}"
            exit
        fi
        echo "xmux-repl-select %arg{1}"
        echo "xmux-repl-launch %arg{2}"
    }
}

define-command xmux-send-to -hidden -params 2..3 %{
    evaluate-commands %sh{
        echo "set-option current xmux_session \"${kak_opt_xmux_session_root}_$1\""
    }
    xmux-repl-select %arg{1}
    xmux-repl-launch
    nop %sh{
        SELECTION=""
        if [ $# -lt 3 ]; then
            SELECTION="${kak_selection}"
        else
            SELECTION="$3"
        fi
        if [ "$2" -eq "1" ]; then
            SELECTION="$(printf "%s" "$SELECTION" | awk '{ print $0 }')"
        fi
        tmux "$kak_opt_xmux_socket_arg" "$kak_opt_xmux_socket" set-buffer -b kak_selection -- "$SELECTION"
        tmux "$kak_opt_xmux_socket_arg" "$kak_opt_xmux_socket" paste-buffer -b kak_selection -t "$kak_opt_xmux_session"
        LAST_CHAR="$(printf "%s" "$SELECTION" | tail -n1 | sed 's/.*\(.\)/\1/')"
        if [ "$LAST_CHAR" = ";" ]; then
            tmux "$kak_opt_xmux_socket_arg" "$kak_opt_xmux_socket" send-keys -t "$kak_opt_xmux_session" '\;'
        fi
        COUNT="$2"
        while [ "$COUNT" -gt "0" ]; do
            tmux "$kak_opt_xmux_socket_arg" "$kak_opt_xmux_socket" send-keys -t "$kak_opt_xmux_session" "ENTER"
            COUNT=$((COUNT-1))
        done
    }
}

}

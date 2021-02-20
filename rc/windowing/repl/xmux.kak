declare-option -docstring "xmux_keep_status" bool xmux_keep_status
declare-option -docstring "xmux_keep_prefix" bool xmux_keep_prefix
declare-option -docstring "xmux_use_public_tmux_socket" bool xmux_use_public_tmux_socket
declare-option -docstring "xmux_session_names" str-list xmux_session_names "a" "b" "c" "d" "e" "f" "s"

hook global ModuleLoaded connect %{
    require-module xmux-repl
}

provide-module xmux-repl %{

declare-option -hidden str xmux_socket
declare-option -hidden str xmux_socket_arg
declare-option -hidden str xmux_session
declare-option -hidden str xmux_conf
declare-option -hidden str xmux_session_root
declare-option -hidden str xmux_session_ext

define-command -docstring %{
    xmux-repl [<arguments>]: create a new window for repl interaction
    All optional parameters are forwarded to the new window
} \
    -params .. \
    -shell-completion \
    xmux-repl %{
    evaluate-commands %sh{
        SOCKET="$kak_opt_xmux_socket"
        if [ -z "$kak_opt_xmux_socket" ]; then
            # SOCKET="$(mktemp -u -t 'kak-xmux-XXXXXXX')"
            SOCKET="$(basename "$(mktemp -u -t 'kak-xmux-XXXXXXX')")"
        fi
        if [ ! -f ~/.xmux.conf ]; then
            touch "~/.xmux.conf"
        fi
        echo "set-option current xmux_conf \"$(realpath ~/.xmux.conf)\""
        SESSION_ROOT="$kak_opt_xmux_session_root"
        if [ -z "$kak_opt_xmux_session_root" ]; then
            SESSION_ROOT="$SOCKET"
            # SESSION_ROOT="$(basename "$SOCKET")"
        fi
        SESSION_EXT="$kak_opt_xmux_session_ext"
        if [ -z "${kak_opt_xmux_session_ext}" ]; then
            SESSION_EXT="a"
            echo "set-option current xmux_session_ext \"$SESSION_EXT\""
        fi
        echo "set-option current xmux_session_root \"$SESSION_ROOT\""
        if [ "$kak_opt_xmux_use_public_tmux_socket" = "true" ]; then
            echo "set-option current xmux_socket \"-q\""
            echo "set-option current xmux_socket_arg \"-q\""
        else
            echo "set-option current xmux_socket \"$SOCKET\""
            echo "set-option current xmux_socket_arg \"-L\""
        fi
        echo "set-option current xmux_session \"${SESSION_ROOT}_$SESSION_EXT\""
    }
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
        echo 'define-command -override xmux-send-text-'$kak_opt_xmux_session_ext' -params 0..1 %{ xmux-send-to "'$kak_opt_xmux_session_ext'" 0 %arg{@} }'
        echo 'define-command -override xmux-send-lines-'$kak_opt_xmux_session_ext' -params 0..1 %{ xmux-send-to "'$kak_opt_xmux_session_ext'" 1 %arg{@} }'
    }
}

define-command xmux-send-to -hidden -params 2..3 %{
    evaluate-commands %sh{
        echo "set-option current xmux_session \"${kak_opt_xmux_session_root}_$1\""
    }
    evaluate-commands %sh{
        if [ -z "$kak_opt_xmux_socket" ]; then
            echo "xmux-repl"
        fi
    }
    nop %sh{
        SELECTION=""
        if [ $# -lt 3 ]; then
            SELECTION="${kak_selection}"
        else
            SELECTION="$3"
        fi
        if [ "$2" -eq "1" ]; then
            SELECTION="$(printf "%s" "$SELECTION" | awk 'BEGIN {LAST_NL=0} { LAST_NL=0; print $0; if (length($0) == 0) LAST_NL=1 } END { if (LAST_NL == 0) print "" }')"
        fi
        tmux "$kak_opt_xmux_socket_arg" "$kak_opt_xmux_socket" set-buffer -b kak_selection -- "$SELECTION"
        tmux "$kak_opt_xmux_socket_arg" "$kak_opt_xmux_socket" paste-buffer -b kak_selection -t "$kak_opt_xmux_session"
        if [ "$2" -eq "1" ]; then
            tmux "$kak_opt_xmux_socket_arg" "$kak_opt_xmux_socket" send-keys -t "$kak_opt_xmux_session" "ENTER"
        fi
    }
}

define-command xmux-send-text -params 0..1 -docstring %{
        xmux-send-text [text]: Send text to the REPL pane.
        If no text is passed, then the selection is used
    } %{
    xmux-send-to %opt{xmux_session_ext} 0 %arg{@}
}

evaluate-commands %sh{
    for X in $kak_opt_xmux_session_names; do
        echo "define-command -params .. -shell-completion xmux-repl-$X %{"
        echo "    set-option current xmux_session_ext \"$X\""
        echo "    xmux-repl %arg{@}"
        echo "}"
    done
}

}

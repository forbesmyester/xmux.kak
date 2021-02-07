hook global ModuleLoaded x11 %{
    require-module xmux-repl
}

provide-module xmux-repl %{

declare-option -docstring "window id of the REPL window" str x11_repl_id
declare-option -docstring "how to connect to x11-tmux" str xmux_socket
declare-option -docstring "how to connect to x11-tmux" str xmux_session
declare-option -docstring "how to connect to x11-tmux" str xmux_config
declare-option -docstring "xmux_default_terminal" str xmux_default_terminal

define-command -docstring %{
    xmux-repl [<arguments>]: create a new window for repl interaction
    All optional parameters are forwarded to the new window
} \
    -params .. \
    -shell-completion \
    xmux-repl %{
    evaluate-commands %sh{
        SOCKET="$(mktemp -u -t 'kak-xmux-XXXXXXX')"
        SESSION="$(basename "$SOCKET")"
        touch "${SOCKET}-config"
        echo "set-option current xmux_socket \"$SOCKET\""
        echo "set-option current xmux_config \"${SOCKET}-config\""
        echo "set-option current xmux_session \"$SESSION\""
        if [ -n "$kak_opt_xmux_default_terminal" ]; then
            printf 'set -g default-terminal "%s"\n' "$kak_opt_xmux_default_terminal" > "${SOCKET}-config"
        fi
    }
    x11-terminal tmux -S %opt{xmux_socket} -f %opt{xmux_config} new-session -s %opt{xmux_session} %arg{@}
    evaluate-commands %sh{
        TMUX_SESSION_COUNT=0
        LOOP_COUNT=0
        while [ "$LOOP_COUNT" -lt 50 ] && [ "$TMUX_SESSION_COUNT" -lt 1 ]; do
            if tmux -S "$kak_opt_xmux_socket" list-sessions 2>&1 | grep "^$kak_opt_xmux_session" > /dev/null; then
                TMUX_SESSION_COUNT=1
            fi
            LOOP_COUNT=$((LOOP_COUNT + 1))
            sleep 0.1
        done
        if [ "$TMUX_SESSION_COUNT" -lt 1 ]; then
            echo "echo Could not re-attach to session"
            exit 1
        fi
        tmux -S "$kak_opt_xmux_socket" set-option -g prefix NONE
        tmux -S "$kak_opt_xmux_socket" set-option -g prefix2 NONE
        tmux -S "$kak_opt_xmux_socket" set status off
    }
}

define-command xmux-send-text -params 0..1 -docstring %{
        xmux-send-text [text]: Send text to the REPL pane.
        If no text is passed, then the selection is used
    } %{
    evaluate-commands %sh{
        if [ -z "$kak_opt_xmux_socket" ]; then
            echo "xmux-repl"
        fi
    }
    nop %sh{
        if [ $# -eq 0 ]; then
            tmux -S "$kak_opt_xmux_socket" set-buffer -b kak_selection -- "${kak_selection}"
        else
            tmux -S "$kak_opt_xmux_socket" set-buffer -b kak_selection -- "$1"
        fi
        tmux -S "$kak_opt_xmux_socket" paste-buffer -b kak_selection -t "$kak_opt_xmux_session"
    }
}

}

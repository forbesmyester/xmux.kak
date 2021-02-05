hook global ModuleLoaded x11 %{
    require-module xmux-repl
}

provide-module xmux-repl %{

declare-option -docstring "window id of the REPL window" str x11_repl_id
declare-option -docstring "how to connect to x11-tmux" str x11_tmux_socket
declare-option -docstring "how to connect to x11-tmux" str x11_tmux_session
declare-option -docstring "how to connect to x11-tmux" str x11_tmux_config

define-command -docstring %{
    xmux-repl [<arguments>]: create a new window for repl interaction
    All optional parameters are forwarded to the new window
} \
    -params .. \
    -shell-completion \
    xmux-repl %{
    evaluate-commands %sh{
        SOCKET="$(mktemp -u -t 'tmux-term-spawn-XXXXXX')"
        SESSION="$(basename "$SOCKET")"
        touch "${SOCKET}-config"
        echo "set-option current x11_tmux_socket \"$SOCKET\""
        echo "set-option current x11_tmux_config \"${SOCKET}-config\""
        echo "set-option current x11_tmux_session \"$SESSION\""
        echo "echo '$SOCKET'"
    }
    x11-terminal tmux -S %opt{x11_tmux_socket} -f %opt{x11_tmux_config} new-session -s %opt{x11_tmux_session} %arg{@}
    evaluate-commands %sh{
        TMUX_SESSION_COUNT=0
        LOOP_COUNT=0
        while [ "$LOOP_COUNT" -lt 50 ] && [ "$TMUX_SESSION_COUNT" -lt 1 ]; do
            if tmux -S "$kak_opt_x11_tmux_socket" list-sessions 2>&1 | grep "^$kak_opt_x11_tmux_session" > /dev/null; then
                TMUX_SESSION_COUNT=1
            fi
            LOOP_COUNT=$((LOOP_COUNT + 1))
            sleep 0.1
        done
        if [ "$TMUX_SESSION_COUNT" -lt 1 ]; then
            echo "echo Could not re-attach to session"
            exit 1
        fi
        tmux -S "$kak_opt_x11_tmux_socket" set-option -g prefix NONE
        tmux -S "$kak_opt_x11_tmux_socket" set-option -g prefix2 NONE
        tmux -S "$kak_opt_x11_tmux_socket" set status off
    }
}

define-command xmux-send-text -params 0..1 -docstring %{
        xmux-send-text [text]: Send text to the REPL pane.
        If no text is passed, then the selection is used
    } %{
    nop %sh{
        if [ $# -eq 0 ]; then
            tmux -S "$kak_opt_x11_tmux_socket" set-buffer -b kak_selection -- "${kak_selection}"
        else
            tmux -S "$kak_opt_x11_tmux_socket" set-buffer -b kak_selection -- "$1"
        fi
        tmux -S "$kak_opt_x11_tmux_socket" paste-buffer -b kak_selection -t "$kak_opt_x11_tmux_session"
    }
}

}

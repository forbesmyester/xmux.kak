hook global ModuleLoaded connect %{
    require-module xmux
}

provide-module xmux %{

declare-option -hidden str xmux_session
declare-option -hidden str-to-str-map xmux_window # todo - convert to dictionary, use session as key
declare-option -hidden str-to-str-map xmux_pane # todo - convert to dictionary, use session as key


define-command -hidden -params 1..2 xmux-repl-ensure-impl %{
    evaluate-commands %sh{
        if xmux exists "$1" "$2"; then
            exit 0
        fi
        echo "connect-terminal xmux new \"$1\" \"$2\""
        echo "xmux-commands \"$2\""
        echo "xmux-reset \"$2\""
    }
}


define-command -hidden -params 1 xmux-commands %{
    evaluate-commands %sh{
        echo "define-command" "-override" "xmux-chars-$1" "-params" "0..1 %{ xmux-chars "$1" %arg{@} }"
        echo "define-command" "-override" "xmux-lines-$1" "-params" "0..1 %{ xmux-lines "$1" %arg{@} }"
        echo "define-command" "-override" "xmux-key-$1" "-params" "1 %{ xmux-key "$1" %arg{@} }"
    }
}


define-command -hidden -params 1 xmux-repl-ensure %{
    xmux-repl-ensure-impl %val{session} %arg{@}
    set-option current xmux_session %arg{1}
}


define-command -params 1 xmux-reset %{
    evaluate-commands %sh{
        xmux wait-for "$kak_session" "$1"
        THE_WIN="$( xmux current-window "$kak_session" "$1" | sed 's/ .*//' )"
        echo "set-option" "-add" "current" "xmux_window" "${1}=$THE_WIN"
        echo "set-option" "-add" "current" "xmux_pane" "${1}=$( xmux current-pane "$kak_session" "$1" "$THE_WIN" )"
    }
}



define-command -params 0 xmux-split %{
    evaluate-commands %sh{
        SOCKET="$(xmux current_socket)"
        if [ "$kak_session" != "$SOCKET" ]; then
            echo "echo 'Kakoune session must be same name as tmux session (KAK_SESSION: $kak_session) != (TMUX_SOCKET $SOCKET)'"
            exit
        fi
        SESSION="$(xmux current_session "$SOCKET")"
        WIN_PANE="$(xmux new "$SOCKET" "$SESSION")"
        THE_WIN="$(echo "$WIN_PANE" | sed 's/ .*//')"
        THE_PANE="$(echo "$WIN_PANE" | sed 's/.* //')"
        echo "set-option current xmux_session '""$SESSION""'"
        echo "set-option" "-add" "current" "xmux_window" "${SESSION}=$THE_WIN"
        echo "set-option" "-add" "current" "xmux_pane" "${SESSION}=$THE_PANE"
        echo "xmux-commands '""$SESSION""'"
    }
}



define-command -hidden -params 1..2 xmux-chars %{
    xmux-send chars %arg{@}
}


define-command -hidden -params 1..2 xmux-lines %{
    xmux-send lines %arg{@}
}


define-command -hidden -params 2..3 xmux-send %{
    xmux-repl-ensure %arg{2}
    nop %sh{
        WIN="$(echo "$kak_opt_xmux_window" | awk -v K="$2" 'BEGIN{ FS="="; RS=" " } $1==K{ print $2 }')"
        PANE="$(echo "$kak_opt_xmux_pane" | awk -v K="$2" 'BEGIN{ FS="="; RS=" " } $1==K{ print $2 }')"
        if [ "$#" -gt 2 ]; then
            printf "%s" "$3" | xmux "$1" "$kak_session" "$2" "$WIN" "$PANE"
        else
            printf "%s" "${kak_selection}" | xmux "$1" "$kak_session" "$2" "$WIN" "$PANE"
        fi
    }
    set-option current xmux_session %arg{2}
}


define-command -hidden -params 2 xmux-key %{
    xmux-repl-ensure %arg{1}
    nop %sh{
        WIN="$(echo "$kak_opt_xmux_window" | awk -v K="$1" 'BEGIN{ FS="="; RS=" " } $1==K{ print $2 }')"
        PANE="$(echo "$kak_opt_xmux_pane" | awk -v K="$1" 'BEGIN{ FS="="; RS=" " } $1==K{ print $2 }')"
        xmux "key" "$kak_session" "$1" "$WIN" "$PANE" "$2"
    }
    set-option current xmux_session %arg{2}
}


define-command -docstring %{
    xmux-repl:          New REPL using $SHELL
    xmux-repl NAME:     New REPL named $NAME
    xmux-repl NAME CMD: New REPL named $NAME sending $CMD
    xmux-repl "" CMD:   New REPL named default sending $CMD
} \
    -params 0..2 \
    -shell-completion \
    xmux-repl %{
    evaluate-commands %sh{
        . "$kak_opt_prelude_path"
        SOCKET="$(xmux current_socket)"
        if [ "$kak_session" = "$SOCKET" ]; then
            echo "xmux-split"
            exit
        fi

        if [ "$#" -eq 0 ]; then
            echo "xmux-repl-ensure default"
            exit
        fi
        if [ "$#" -eq 1 ]; then
            echo "xmux-repl-ensure %arg{1}"
            exit
        fi
        if [ "$1" = "" ]; then
            echo "xmux-lines 'default' %arg{2}"
            exit
        fi
        echo "xmux-lines %arg{1} %arg{2}"
    }
}


}

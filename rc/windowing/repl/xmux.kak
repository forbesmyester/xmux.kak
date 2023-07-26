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
    }
}


define-command -params 1 xmux-commands -docstring %{
    xmux-commands NAME: defines commands for NAME
} %{
    evaluate-commands %sh{
        echo "define-command" "-override" "xmux-chars-$1" "-params" "0..1 %{ xmux-chars "$1" %arg{@} }"
        echo "define-command" "-override" "xmux-lines-$1" "-params" "0..1 %{ xmux-lines "$1" %arg{@} }"
        echo "define-command" "-override" "xmux-key-$1" "-params" "1 %{ xmux-key "$1" %arg{@} }"
        echo declare-option str "xmux_lines_${1}_before_lines_pre_key" ""
        echo declare-option str "xmux_lines_${1}_before_lines" ""
        echo declare-option str "xmux_lines_${1}_before_lines_post_key" ""
        echo declare-option str "xmux_lines_${1}_after_lines_pre_key" ""
        echo declare-option str "xmux_lines_${1}_after_lines" ""
        echo declare-option str "xmux_lines_${1}_after_lines_post_key" ""
    }
    evaluate-commands %sh{
        echo "xmux-reset \"$1\""
    }
    set-option global xmux_session %arg{1}
}


define-command -hidden -params 1 xmux-repl-ensure %{
    xmux-repl-ensure-impl %val{session} %arg{@}
    set-option global xmux_session %arg{1}
}


define-command -hidden -params 1 xmux-reset %{
    evaluate-commands %sh{
        xmux wait-for "$kak_session" "$1"
        THE_WIN="$( xmux current-window "$kak_session" "$1" | sed 's/ .*//' )"
        echo "set-option" "-add" "global" "xmux_window" "${1}=$THE_WIN"
        echo "set-option" "-add" "global" "xmux_pane" "${1}=$( xmux current-pane "$kak_session" "$1" "$THE_WIN" )"
    }
}



define-command -params 0 xmux-split %{
    evaluate-commands %sh{
        SOCKET="$(xmux current_socket)"
        if [ "$kak_session" != "$SOCKET" ]; then
            echo "echo 'Kakoune session must be same name as tmux session $kak_session != $SOCKET'"
            exit
        fi
        SESSION="$(xmux current_session "$SOCKET")"
        WIN_PANE="$(xmux new "$SOCKET" "$SESSION")"
        THE_WIN="$(echo "$WIN_PANE" | sed 's/ .*//')"
        THE_PANE="$(echo "$WIN_PANE" | sed 's/.* //')"
        echo "set-option global xmux_session '""$SESSION""'"
        echo "xmux-commands '""$SESSION""'"
    }
}



define-command -hidden -params 1..2 xmux-chars %{
    xmux-send 1 chars %arg{@}
}


define-command -hidden -params 1..2 xmux-lines %{

    evaluate-commands %sh{
        gawk -v REPL="$1" '
            BEGIN {
                printf "xmux-key %s %s%s%s\n", REPL, "%opt{xmux_lines_", REPL, "_before_lines_pre_key}"
                printf "xmux-send 0 lines %s %s%s%s\n", REPL, "%opt{xmux_lines_", REPL, "_before_lines}"
                printf "xmux-key %s %s%s%s\n", REPL, "%opt{xmux_lines_", REPL, "_before_lines_post_key}"
                printf "xmux-send 1 lines %%arg{@}\n"
                printf "xmux-key %s %s%s%s\n", REPL, "%opt{xmux_lines_", REPL, "_after_lines_pre_key}"
                printf "xmux-send 0 lines %s %s%s%s\n", REPL, "%opt{xmux_lines_", REPL, "_after_lines}"
                printf "xmux-key %s %s%s%s\n", REPL, "%opt{xmux_lines_", REPL, "_after_lines_post_key}"
            }'
    }

    # xmux-send 1 lines %arg{@}
}

define-command xmux-selected-key -params 1  %{
    xmux-key "%opt{xmux_session}" "%arg{1}"
}

define-command xmux-selected-lines -params 0  %{
    xmux-lines "%opt{xmux_session}"
}

define-command xmux-session-list %{
    declare-option -hidden str-list xmux_session_list 
    set-option global xmux_session_list ""
    evaluate-commands %sh{
        echo "$kak_opt_xmux_window" | awk -v K="$kak_opt_xmux_session" 'BEGIN{ FS="="; RS=" " } { IS_CUR="" } $1==K{ IS_CUR="*" } { printf "set-option -add global xmux_session_list \"%s%s\"\n", IS_CUR, $1}'
    }
    info -title "xmux sessions" -- "%opt{xmux_session_list}"
}

define-command -hidden -params 3..4 xmux-send %{
    xmux-repl-ensure %arg{3}
    nop %sh{
        if [ "$1" -eq "0" ]; then
            if [ "$#" -lt 4 ]; then
                exit
            fi
            if [ "$4" = "" ]; then
                exit
            fi
        fi
        # echo "1 $1 ; 2 $2 ; 3 $3 ; 4 $4" >> ll
        WIN="$(echo "$kak_opt_xmux_window" | awk -v K="$3" 'BEGIN{ FS="="; RS=" " } $1==K{ print $2 }')"
        PANE="$(echo "$kak_opt_xmux_pane" | awk -v K="$3" 'BEGIN{ FS="="; RS=" " } $1==K{ print $2 }')"
        if [ "$#" -gt 3 ]; then
            printf "%s" "$4" | xmux "$2" "$kak_session" "$3" "$WIN" "$PANE"
        else
            printf "%s" "${kak_selection}" | xmux "$2" "$kak_session" "$3" "$WIN" "$PANE"
        fi
    }
    set-option global xmux_session %arg{3}
}


define-command -hidden -params 2 xmux-key %{
    xmux-repl-ensure %arg{1}
    nop %sh{
        if [ "$2" != "" ]; then
            WIN="$(echo "$kak_opt_xmux_window" | awk -v K="$1" 'BEGIN{ FS="="; RS=" " } $1==K{ print $2 }')"
            PANE="$(echo "$kak_opt_xmux_pane" | awk -v K="$1" 'BEGIN{ FS="="; RS=" " } $1==K{ print $2 }')"
            xmux "key" "$kak_session" "$1" "$WIN" "$PANE" "$2"
        fi
    }
    set-option global xmux_session %arg{1}
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
        if [ "$#" -eq 0 ]; then
            echo "xmux-repl-ensure default"
            exit
        fi
        if [ "$#" -eq 1 ]; then
            echo "xmux-repl-ensure %arg{1}"
            exit
        fi
        if [ "$1" = "" ]; then
            # echo "xmux-repl-ensure 'default'"
            echo "xmux-lines 'default' %arg{2}"
            exit
        fi
        # echo "xmux-repl-ensure %arg{1}"
        echo "xmux-lines %arg{1} %arg{2}"
    }
}


}

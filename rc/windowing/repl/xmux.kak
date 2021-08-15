hook global ModuleLoaded connect %{
    require-module xmux
}

provide-module xmux %{

declare-option -hidden str xmux_session

define-command -hidden xmux-incrment-session-ext %{
    evaluate-commands %sh{
    }
}


define-command -hidden -params 1..2 xmux-repl-ensure-impl %{
    evaluate-commands %sh{
        if xmux exists "$1" "$2"; then
            exit 0
        fi
        echo "connect-terminal xmux new \"$1\" \"$2\""
    }
}

define-command -hidden -params 0..1 xmux-repl-ensure %{
    xmux-repl-ensure-impl %val{session} %arg{@}
    evaluate-commands %sh{
        echo "define-command" "-override" "xmux-chars-$1" "-params" "0..1 %{ xmux-chars "$1" %arg{@} }"
        echo "define-command" "-override" "xmux-lines-$1" "-params" "0..1 %{ xmux-lines "$1" %arg{@} }"
    }
    set-option current xmux_session %arg{1}
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
        if [ "$#" -gt 2 ]; then
            printf "%s" "$3" | xmux "$1" $kak_session "$2"
        else
            printf "%s" "${kak_selection}" | xmux "$1" $kak_session "$2"
        fi
    }
    set-option current xmux_session %arg{1}
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

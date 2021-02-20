# xmux.kak

Kakoune external REPL which uses tmux for comms

## What is it

I like the fact that the inbuild X11 REPL creates external windows.

What I do not like is the fact that when I send text to it, it uses `xdotool`to switch windows / focus.

I like the fact that the tmux REPL uses sockets for communication as it's not switching windows / focus.

This Kakoune plugin blends these two ideas and provides a REPL that is launched in an external window but uses a TMUX socket for communication... I think this is the best of both worlds.

## Installation

 * Install [plug.kak](https://github.com/robertmeta/plug.kak);
 * Install [connect.kak](https://github.com/alexherbo2/connect.kak)
 * Put `plug "forbesmyester/xmux.kak"` in your ~/.config/kak/kakrc.

## Usage

Provides two commands `xmux-repl`, `xmux-send-text` and `xmux-send-lines` which spawn a REPL, send text and send lines to that REPL respectively.

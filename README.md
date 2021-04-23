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
 * Put `xmux` from [xmux](https://github.com/forbesmyester/xmux) somewhere in your path and make sure it's executable.
 * Put `plug "forbesmyester/xmux.kak"` in your ~/.config/kak/kakrc.
 * Run `:plug-install` within Kakoune

## Usage

Provides just one commands `xmux-repl` which spawn a REPL. When you use this command it will attach more commands such as:

 * `xmux-chars-bob` would be created by a `:xmux-repl bob` and it will send any characters passed to it to the REPL.
 * `xmux-lines-bob` like `xmux-chars-bob`, but it will ensure a new line is sent afterwards.

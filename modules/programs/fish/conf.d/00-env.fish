if status is-login
    fish_add_path $HOME/.local/bin $HOME/.cargo/bin
end

set -gx MANROFFOPT -c
set -gx MANPAGER "bat -l man -p"

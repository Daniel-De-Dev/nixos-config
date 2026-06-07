set -gx FZF_DEFAULT_COMMAND "fd --type f --hidden --exclude .git"
set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -gx FZF_ALT_C_COMMAND "fd --type d --hidden --exclude .git"

set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border --info=inline"

if status is-interactive
    if type -q fzf_configure_bindings
        eval 'fzf_configure_bindings --directory=\ct --git_log=\cg --history=\cr --variables=\cv'
    end
end

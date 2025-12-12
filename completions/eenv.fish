function __eenv_list_envs
    set -l envdir
    if set -q EENV_ROOT
        set envdir "$EENV_ROOT/envs"
    else
        set envdir "$HOME/.config/fish/eenv/envs"
    end

    if not test -d "$envdir"
        return
    end

    set -l files (command find -- "$envdir" -maxdepth 1 -type f -name '*.env' 2>/dev/null | command sort)
    for file in $files
        string replace -r '^.*/' '' -- "$file" | string replace -r '\.env$' ''
    end
end

complete -c eenv -f

complete -c eenv -n 'not __fish_seen_subcommand_from create new activate enable deactivate disable edit list ls describe desc --help -h --auto-restore' -a 'create' -d 'Create a new env file'
complete -c eenv -n 'not __fish_seen_subcommand_from create new activate enable deactivate disable edit list ls describe desc --help -h --auto-restore' -a 'new' -d 'Create a new env file'
complete -c eenv -n 'not __fish_seen_subcommand_from create new activate enable deactivate disable edit list ls describe desc --help -h --auto-restore' -a 'activate' -d 'Activate env, removing vars from previously active env'
complete -c eenv -n 'not __fish_seen_subcommand_from create new activate enable deactivate disable edit list ls describe desc --help -h --auto-restore' -a 'enable' -d 'Activate env, removing vars from previously active env'
complete -c eenv -n 'not __fish_seen_subcommand_from create new activate enable deactivate disable edit list ls describe desc --help -h --auto-restore' -a 'deactivate' -d 'Deactivate current environment'
complete -c eenv -n 'not __fish_seen_subcommand_from create new activate enable deactivate disable edit list ls describe desc --help -h --auto-restore' -a 'disable' -d 'Deactivate current environment'
complete -c eenv -n 'not __fish_seen_subcommand_from create new activate enable deactivate disable edit list ls describe desc --help -h --auto-restore' -a 'edit' -d 'Edit active env or the one passed'
complete -c eenv -n 'not __fish_seen_subcommand_from create new activate enable deactivate disable edit list ls describe desc --help -h --auto-restore' -a 'list' -d 'List envs and show the active one'
complete -c eenv -n 'not __fish_seen_subcommand_from create new activate enable deactivate disable edit list ls describe desc --help -h --auto-restore' -a 'ls' -d 'List envs and show the active one'
complete -c eenv -n 'not __fish_seen_subcommand_from create new activate enable deactivate disable edit list ls describe desc --help -h --auto-restore' -a 'describe' -d 'Show variables in active env or the one passed'
complete -c eenv -n 'not __fish_seen_subcommand_from create new activate enable deactivate disable edit list ls describe desc --help -h --auto-restore' -a 'desc' -d 'Show variables in active env or the one passed'
complete -c eenv -n 'not __fish_seen_subcommand_from create new activate enable deactivate disable edit list ls describe desc --help -h --auto-restore' -a '--help' -d 'Show help message'
complete -c eenv -n 'not __fish_seen_subcommand_from create new activate enable deactivate disable edit list ls describe desc --help -h --auto-restore' -a '-h' -d 'Show help message'

complete -c eenv -n '__fish_seen_subcommand_from activate enable' -x -a '(__eenv_list_envs)' -d 'Environment name'
complete -c eenv -n '__fish_seen_subcommand_from edit' -x -a '(__eenv_list_envs)' -d 'Environment name'
complete -c eenv -n '__fish_seen_subcommand_from describe desc' -x -a '(__eenv_list_envs)' -d 'Environment name'

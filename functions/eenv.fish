function __eenv_root
    if set -q EENV_ROOT
        echo "$EENV_ROOT"
    else
        echo "$HOME/.config/fish/eenv"
    end
end

function __eenv_env_dir
    echo (__eenv_root)/envs
end

function __eenv_env_file -a name
    echo (__eenv_env_dir)/"$name".env
end

function __eenv_active_file
    echo (__eenv_root)/active
end

function __eenv_ensure_dirs
    command mkdir -p -- (__eenv_env_dir)
end

function __eenv_vars_from_file -a file
    if not test -f "$file"
        return 1
    end

    set -l vars
    while read -l line
        set line (string trim $line)
        if test -z "$line"
            continue
        end
        if string match -qr '^#' -- $line
            continue
        end

        set -l key (string replace -r '=.*$' '' -- $line)
        set key (string trim -c ' \t' -- $key)
        if test -n "$key"
            set vars $vars $key
        end
    end < "$file"

    echo $vars
end

function __eenv_unload_env -a name
    set -l file (__eenv_env_file $name)
    if not test -f "$file"
        return
    end

    for var in (__eenv_vars_from_file "$file")
        # Remove exported globals to fully drop previously set env vars.
        set -e -gx $var
    end
end

function __eenv_load_env -a name
    set -l file (__eenv_env_file $name)
    if not test -f "$file"
        printf 'eenv: env "%s" not found at %s\n' "$name" "$file" >&2
        return 1
    end

    set -l had_error 0
    while read -l line
        set line (string trim $line)
        if test -z "$line"
            continue
        end
        if string match -qr '^#' -- $line
            continue
        end
        if not string match -q '*=*' -- $line
            printf 'eenv: skip invalid line in %s: %s\n' "$file" "$line" >&2
            set had_error 1
            continue
        end

        set -l parts (string split -m1 '=' -- $line)
        set -l key (string trim -c ' \t' -- $parts[1])
        set -l value ""
        if test (count $parts) -ge 2
            set value (string trim -c ' \t' -- $parts[2])
        end
        set -l is_quoted 0
        set -l vlen (string length -- $value)
        if test $vlen -ge 2
            set -l first (string sub -s 1 -l 1 -- $value)
            set -l last (string sub -s -1 -l 1 -- $value)
            if test $first = '"'; and test $last = '"'
                set value (string sub -s 2 -e -2 -- $value)
                set is_quoted 1
            else if test $first = "'"; and test $last = "'"
                set value (string sub -s 2 -e -2 -- $value)
                set is_quoted 1
            end
        end

        if test $is_quoted -eq 0
            # Strip inline comment for unquoted values only.
            set value (string replace -r '\s+#.*$' '' -- $value)
            set value (string trim -c ' \t' -- $value)
        end

        if test -n "$key"
            set -gx $key $value
        end
    end < "$file"

    return $had_error
end

function __eenv_set_active -a name
    __eenv_ensure_dirs
    set -l active_file (__eenv_active_file)
    printf '%s\n' "$name" > "$active_file"
end

function __eenv_current_active
    set -l file (__eenv_active_file)
    if not test -f "$file"
        return 1
    end

    read -l name < "$file"
    if test -n "$name"
        echo "$name"
        return 0
    end

    return 1
end

function __eenv_create -a name
    if test -z "$name"
        printf 'Usage: eenv create <name>\n' >&2
        return 1
    end

    __eenv_ensure_dirs
    set -l file (__eenv_env_file $name)
    if test -e "$file"
        printf 'eenv: env "%s" already exists at %s\n' "$name" "$file" >&2
        return 1
    end

    printf '# KEY=VALUE pairs. Lines starting with # are ignored.\n' > "$file"
    printf '# Example:\n# FOO=bar\n# PATH=/custom/bin:$PATH\n\n' >> "$file"

    printf 'Created %s\n' "$file"
end

function __eenv_list
    __eenv_ensure_dirs
    set -l envdir (__eenv_env_dir)
    set -l active (__eenv_current_active)
    set -l files (command find -- "$envdir" -maxdepth 1 -type f -name '*.env' 2>/dev/null | command sort)

    if test (count $files) -eq 0
        echo 'No envs created yet.'
        return 0
    end

    for file in $files
        set -l name (string replace -r '^.*/' '' -- "$file" | string replace -r '\.env$' '')
        if test "$name" = "$active"
            echo "* $name (active)"
        else
            echo "  $name"
        end
    end
end

function __eenv_edit -a name
    set -l active (__eenv_current_active)
    if test -z "$name"
        if test -z "$active"
            echo 'eenv: no active env. Pass a name to edit.' >&2
            return 1
        end
        set name $active
    end

    __eenv_ensure_dirs
    set -l file (__eenv_env_file $name)
    if not test -f "$file"
        printf 'eenv: env "%s" not found at %s. Create it first.\n' "$name" "$file" >&2
        return 1
    end

    set -l editor_cmd $EDITOR
    if test -z "$editor_cmd"
        set editor_cmd vi
    end

    if test (count $editor_cmd) -gt 1
        command $editor_cmd -- "$file"
    else
        set -l editor_parts (string split ' ' -- $editor_cmd)
        if test (count $editor_parts) -gt 1
            command $editor_parts[1] $editor_parts[2..-1] -- "$file"
        else
            command "$editor_cmd" -- "$file"
        end
    end
end

function __eenv_activate -a name
    if test -z "$name"
        printf 'Usage: eenv activate <name>\n' >&2
        return 1
    end

    __eenv_ensure_dirs
    set -l file (__eenv_env_file $name)
    if not test -f "$file"
        printf 'eenv: env "%s" does not exist at %s\n' "$name" "$file" >&2
        return 1
    end

    set -l active (__eenv_current_active)
    if test "$active" = "$name"
        printf 'eenv: "%s" is already active\n' "$name"
        return 0
    end

    if test -n "$active"
        __eenv_unload_env "$active"
    end

    __eenv_load_env "$name"
    set -l load_status $status
    __eenv_set_active "$name"
    printf 'Activated "%s"\n' "$name"
    if test $load_status -ne 0
        echo 'Note: some lines were skipped because they were invalid.'
    end
end

function __eenv_describe -a name
    set -l active (__eenv_current_active)
    if test -z "$name"
        if test -z "$active"
            echo 'eenv: no active env. Pass a name to describe.' >&2
            return 1
        end
        set name $active
    end

    set -l file (__eenv_env_file $name)
    if not test -f "$file"
        printf 'eenv: env "%s" not found at %s\n' "$name" "$file" >&2
        return 1
    end

    set -l has_vars 0
    printf 'Variables in "%s":\n' "$name"

    while read -l line
        set line (string trim $line)
        if test -z "$line"
            continue
        end
        if string match -qr '^#' -- $line
            continue
        end
        if not string match -q '*=*' -- $line
            continue
        end

        set -l parts (string split -m1 '=' -- $line)
        set -l key (string trim -c ' \t' -- $parts[1])
        if test -z "$key"
            continue
        end

        set -l value ""
        if test (count $parts) -ge 2
            set value (string trim -c ' \t' -- $parts[2])
        end

        set -l is_quoted 0
        set -l vlen (string length -- $value)
        if test $vlen -ge 2
            set -l first (string sub -s 1 -l 1 -- $value)
            set -l last (string sub -s -1 -l 1 -- $value)
            if test $first = '"'; and test $last = '"'
                set value (string sub -s 2 -e -2 -- $value)
                set is_quoted 1
            else if test $first = "'"; and test $last = "'"
                set value (string sub -s 2 -e -2 -- $value)
                set is_quoted 1
            end
        end

        if test $is_quoted -eq 0
            set value (string replace -r '\s+#.*$' '' -- $value)
            set value (string trim -c ' \t' -- $value)
        end

        set -l key_lower (string lower -- "$key")
        set -l should_mask 0
        if string match -qr '.*(token|key|secret|pass).*' -- "$key_lower"
            set should_mask 1
        end

        if test $should_mask -eq 1
            set -l val_len (string length -- "$value")
            if test $val_len -le 6
                set value "***"
            else
                set -l prefix (string sub -s 1 -l 2 -- "$value")
                set -l suffix (string sub -s -2 -l 2 -- "$value")
                set -l stars (string repeat -n (math $val_len - 4) '*')
                set value "$prefix$stars$suffix"
            end
        end

        printf '  %s=%s\n' "$key" "$value"
        set has_vars 1
    end < "$file"

    if test $has_vars -eq 0
        printf 'eenv: env "%s" contains no variables\n' "$name"
        return 0
    end
end

function __eenv_usage
    echo 'Usage:'
    echo '  eenv create <name>    Create a new env file'
    echo '  eenv activate <name>  Activate env, removing vars from previously active env'
    echo '  eenv edit [name]      Edit active env or the one passed'
    echo '  eenv list             List envs and show the active one'
    echo '  eenv describe [name]  Show variables in active env or the one passed'
end

function __eenv_restore_active
    set -l active (__eenv_current_active)
    if test -z "$active"
        return
    end

    __eenv_load_env "$active" >/dev/null 2>/dev/null
end

function eenv
    set -l cmd $argv[1]

    switch $cmd
        case '' '-h' '--help'
            __eenv_usage
        case 'create' 'new'
            __eenv_create $argv[2]
        case 'activate' 'enable'
            __eenv_activate $argv[2]
        case 'edit'
            if test (count $argv) -gt 2
                echo 'Usage: eenv edit [name]' >&2
                return 1
            end
            __eenv_edit $argv[2]
        case 'list' 'ls'
            __eenv_list
        case 'describe' 'desc'
            if test (count $argv) -gt 2
                echo 'Usage: eenv describe [name]' >&2
                return 1
            end
            __eenv_describe $argv[2]
        case '--auto-restore'
            __eenv_restore_active
        case '*'
            printf 'eenv: unknown command "%s"\n' "$cmd" >&2
            __eenv_usage
            return 1
    end
end

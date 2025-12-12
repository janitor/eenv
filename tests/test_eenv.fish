#!/usr/bin/env fish

set -g TEST_DIR (mktemp -d)
set -g TEST_ROOT "$TEST_DIR/eenv"
set -gx EENV_ROOT "$TEST_ROOT"

set -g TESTS_PASSED 0
set -g TESTS_FAILED 0

function test_assert -a condition message
    set -l cmd "if $condition; true; else; false; end"
    if eval $cmd
        set -g TESTS_PASSED (math $TESTS_PASSED + 1)
        echo "✓ $message"
        return 0
    else
        set -g TESTS_FAILED (math $TESTS_FAILED + 1)
        echo "✗ $message"
        return 1
    end
end

function test_assert_equal -a actual expected message
    if test "$actual" = "$expected"
        set -g TESTS_PASSED (math $TESTS_PASSED + 1)
        echo "✓ $message"
        return 0
    else
        set -g TESTS_FAILED (math $TESTS_FAILED + 1)
        echo "✗ $message (expected: '$expected', got: '$actual')"
        return 1
    end
end

function test_assert_contains -a text pattern message
    if string match -q "*$pattern*" -- "$text"
        set -g TESTS_PASSED (math $TESTS_PASSED + 1)
        echo "✓ $message"
        return 0
    else
        set -g TESTS_FAILED (math $TESTS_FAILED + 1)
        echo "✗ $message (pattern '$pattern' not found in '$text')"
        return 1
    end
end

function test_setup
    set -gx EENV_ROOT "$TEST_ROOT"
    source functions/eenv.fish
    command rm -rf -- "$TEST_ROOT"
    command mkdir -p -- "$TEST_ROOT/envs"
end

function test_teardown
    command rm -rf -- "$TEST_DIR"
    set -e EENV_ROOT
end

function test_create_env
    test_setup
    
    eenv create testenv
    test_assert "test -f $TEST_ROOT/envs/testenv.env" "create creates env file"
    
    set content (cat "$TEST_ROOT/envs/testenv.env")
    test_assert_contains "$content" "KEY=VALUE" "create adds template content"
    
    test_teardown
end

function test_create_env_alias
    test_setup
    
    eenv new testenv2
    test_assert "test -f $TEST_ROOT/envs/testenv2.env" "new alias creates env file"
    
    test_teardown
end

function test_create_duplicate_fails
    test_setup
    
    eenv create testenv
    set result (eenv create testenv 2>&1)
    test_assert_contains "$result" "already exists" "create fails on duplicate"
    
    test_teardown
end

function test_activate_env
    test_setup
    
    printf 'FOO=bar\nBAZ=qux\n' > "$TEST_ROOT/envs/testenv.env"
    
    eenv activate testenv
    test_assert_equal "$FOO" "bar" "activate sets FOO variable"
    test_assert_equal "$BAZ" "qux" "activate sets BAZ variable"
    test_assert "test -f $TEST_ROOT/active" "activate creates active file"
    test_assert_equal (cat "$TEST_ROOT/active") "testenv" "activate writes correct name to active file"
    
    test_teardown
end

function test_activate_env_alias
    test_setup
    
    printf 'TEST_VAR=value\n' > "$TEST_ROOT/envs/testenv.env"
    
    eenv enable testenv
    test_assert_equal "$TEST_VAR" "value" "enable alias activates env"
    
    test_teardown
end

function test_activate_switches_env
    test_setup
    
    printf 'VAR1=value1\n' > "$TEST_ROOT/envs/env1.env"
    printf 'VAR2=value2\n' > "$TEST_ROOT/envs/env2.env"
    
    eenv activate env1
    test_assert_equal "$VAR1" "value1" "first env sets VAR1"
    
    eenv activate env2
    test_assert_equal "$VAR2" "value2" "second env sets VAR2"
    test_assert "not set -q VAR1" "switching env removes VAR1"
    
    test_teardown
end

function test_deactivate_env
    test_setup
    
    printf 'TEST_VAR=test_value\n' > "$TEST_ROOT/envs/testenv.env"
    
    eenv activate testenv
    test_assert "set -q TEST_VAR" "TEST_VAR is set before deactivate"
    set -l test_var_value "$TEST_VAR"
    test_assert_equal "$test_var_value" "test_value" "TEST_VAR has correct value before deactivate"
    
    eenv deactivate
    set -l var_exists (set -q TEST_VAR; echo $status)
    test_assert "test $var_exists -ne 0" "deactivate removes variables"
    test_assert "not test -f $TEST_ROOT/active" "deactivate removes active file"
    
    test_teardown
end

function test_deactivate_no_active_env
    test_setup
    
    set result (eenv deactivate 2>&1)
    test_assert_contains "$result" "no active environment" "deactivate fails when no active env"
    
    test_teardown
end

function test_list_envs
    test_setup
    
    printf 'VAR1=value1\n' > "$TEST_ROOT/envs/env1.env"
    printf 'VAR2=value2\n' > "$TEST_ROOT/envs/env2.env"
    
    set output (eenv list)
    test_assert_contains "$output" "env1" "list shows env1"
    test_assert_contains "$output" "env2" "list shows env2"
    
    eenv activate env1
    set output (eenv list)
    test_assert_contains "$output" "* env1 (active)" "list marks active env"
    
    test_teardown
end

function test_list_empty
    test_setup
    
    set output (eenv list)
    test_assert_contains "$output" "No envs created yet" "list shows message when empty"
    
    test_teardown
end

function test_describe_env
    test_setup
    
    printf 'FOO=bar\nBAZ=qux\n' > "$TEST_ROOT/envs/testenv.env"
    
    set output (eenv describe testenv)
    test_assert_contains "$output" "FOO=bar" "describe shows FOO variable"
    test_assert_contains "$output" "BAZ=qux" "describe shows BAZ variable"
    
    test_teardown
end

function test_describe_masks_sensitive
    test_setup
    
    printf 'API_TOKEN=secret123456\nPASSWORD=pass123\nKEY=short\n' > "$TEST_ROOT/envs/testenv.env"
    
    set output (eenv describe testenv)
    test_assert_contains "$output" "API_TOKEN" "describe shows API_TOKEN name"
    set -l has_secret (string match -q '*secret123456*' -- "$output"; echo $status)
    test_assert "test $has_secret -ne 0" "describe masks API_TOKEN value"
    test_assert_contains "$output" "PASSWORD" "describe shows PASSWORD name"
    set -l has_pass (string match -q '*pass123*' -- "$output"; echo $status)
    test_assert "test $has_pass -ne 0" "describe masks PASSWORD value"
    test_assert_contains "$output" "KEY=" "describe shows KEY name"
    set -l has_short (string match -q '*KEY=***' -- "$output"; echo $status)
    test_assert "test $has_short -eq 0" "describe masks short KEY value"
    
    test_teardown
end

function test_describe_active_env
    test_setup
    
    printf 'ACTIVE_VAR=active_value\n' > "$TEST_ROOT/envs/testenv.env"
    
    eenv activate testenv
    set output (eenv describe)
    test_assert_contains "$output" "ACTIVE_VAR=active_value" "describe without args shows active env"
    
    test_teardown
end

function test_vars_from_file
    test_setup
    
    printf '# Comment\nFOO=bar\n  BAZ = qux  \nEMPTY=\n' > "$TEST_ROOT/envs/testenv.env"
    
    set vars (__eenv_vars_from_file "$TEST_ROOT/envs/testenv.env")
    test_assert_contains "$vars" "FOO" "vars_from_file extracts FOO"
    test_assert_contains "$vars" "BAZ" "vars_from_file extracts BAZ"
    test_assert_contains "$vars" "EMPTY" "vars_from_file extracts EMPTY"
    test_assert "not string match -q '*Comment*' -- $vars" "vars_from_file ignores comments"
    
    test_teardown
end

function test_load_env_with_quotes
    test_setup
    
    printf 'QUOTED="value with spaces"\nSINGLE_QUOTED='\''single value'\''\n' > "$TEST_ROOT/envs/testenv.env"
    
    eenv activate testenv
    test_assert "set -q QUOTED" "QUOTED variable is set"
    test_assert_contains "$QUOTED" "value" "load_env handles double quotes"
    test_assert "set -q SINGLE_QUOTED" "SINGLE_QUOTED variable is set"
    test_assert_contains "$SINGLE_QUOTED" "single" "load_env handles single quotes"
    
    test_teardown
end

function test_load_env_with_comments
    test_setup
    
    printf 'VAR1=value1 # inline comment\nVAR2=value2\n' > "$TEST_ROOT/envs/testenv.env"
    
    eenv activate testenv
    test_assert_equal "$VAR1" "value1" "load_env strips inline comments"
    test_assert_equal "$VAR2" "value2" "load_env preserves value without comment"
    
    test_teardown
end

function test_usage
    test_setup
    
    set output (eenv --help)
    test_assert_contains "$output" "Usage:" "help shows usage"
    test_assert_contains "$output" "create" "help shows create command"
    test_assert_contains "$output" "activate" "help shows activate command"
    
    test_teardown
end

function test_unknown_command
    test_setup
    
    set output (eenv unknown_cmd 2>&1)
    test_assert_contains "$output" "unknown command" "unknown command shows error"
    
    test_teardown
end

function run_tests
    echo "Running eenv tests..."
    echo ""
    
    test_create_env
    test_create_env_alias
    test_create_duplicate_fails
    test_activate_env
    test_activate_env_alias
    test_activate_switches_env
    test_deactivate_env
    test_deactivate_no_active_env
    test_list_envs
    test_list_empty
    test_describe_env
    test_describe_masks_sensitive
    test_describe_active_env
    test_vars_from_file
    test_load_env_with_quotes
    test_load_env_with_comments
    test_usage
    test_unknown_command
    
    echo ""
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    
    if test $TESTS_FAILED -eq 0
        echo "All tests passed!"
        return 0
    else
        echo "Some tests failed!"
        return 1
    end
end

if test (basename (status --current-filename)) = "test_eenv.fish"
    run_tests
end


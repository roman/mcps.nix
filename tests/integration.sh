#!/usr/bin/env bash
set -euo pipefail

# Default colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
for arg in "$@"; do
    if [ "$arg" = "--no-color" ] || [ "$arg" = "-n" ]; then
        # If --no-color is specified, set all colors to empty strings
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        NC=''
    fi
done

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS+=("$1")
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_summary() {
    echo
    echo "========================================"
    echo -e "${BLUE}Test Summary${NC}"
    echo "========================================"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo
        echo -e "${RED}Failed tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  - $test"
        done
    fi
    echo
}

# Handle Ctrl-C (SIGINT)
trap 'echo -e "\n${YELLOW}[WARNING]${NC} Test interrupted by user"; print_summary; exit 130' INT

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log_info "Running test: $test_name"
    
    local output
    if output=$(eval "$test_command" 2>&1); then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        echo -e "${YELLOW}┌─ Command output ────────────────────────────${NC}"
        echo -e "${YELLOW}│${NC} Command: $test_command"
        echo -e "${YELLOW}│${NC}"
        
        # Process output line by line to add the left border
        while IFS= read -r line; do
            echo -e "${YELLOW}│${NC} $line"
        done <<< "$output"
        
        echo -e "${YELLOW}└────────────────────────────────────────────${NC}"
        return 0
    fi
}

# Test devenv module
test_devenv_module() {
    log_info "=== Testing devenv module ==="

    pushd tests/fixtures/devenv-test 2>&1 > /dev/null

    # Test 1: Shell builds successfully
    run_test "devenv shell builds" "nix develop --impure --command echo loaded"
    
    # Test 2: Claude code is available in shell
    run_test "claude-code available in devenv" "nix develop --impure --command which claude"
    
    # Test 3: MCP configuration file is generated
    run_test "MCP config generation" "nix develop --impure --command test -f .mcp.json"
    
    # Test 4: MCP servers are configured
    run_test "MCP servers configured" "nix develop --impure --command bash -c 'claude mcp list | wc -l | grep -v \"^0$\"'"
    
    # Test 5: Asana MCP server is available
    run_test "Asana MCP server available" "nix develop --impure --command bash -c 'claude mcp list | grep -q asana'"
    
    # Test 6: GitHub MCP server is available  
    run_test "GitHub MCP server available" "nix develop --impure --command bash -c 'claude mcp list | grep -q github'"
    
    # Test 7: Emacs dir-locals file is generated (when supportEmacs = true)
    run_test "Emacs dir-locals generation" "nix develop --impure --command test -f .dir-locals.el"

    popd 2>&1 > /dev/null
}

# Test home-manager module
test_home_manager_module() {
    log_info "=== Testing home-manager module ==="
    
    pushd tests/fixtures/home-manager-test 2>&1 > /dev/null
    
    # Test 1: Home-manager configuration builds
    run_test "home-manager config builds" "nix build .#homeConfigurations.test.activationPackage --dry-run"
    
    # Test 2: Configuration evaluation succeeds
    run_test "home-manager config evaluation" "nix eval .#homeConfigurations.test.config.programs.claude-code.enable"
    
    # Test 3: MCP servers are properly configured
    run_test "home-manager MCP config" "nix eval .#homeConfigurations.test.config.programs.claude-code.mcp.git.enable"

    popd 2>&1 > /dev/null
}

# Test module options and validation
test_module_options() {
    log_info "=== Testing module options ==="
    
    # Test 1: devenv module options are accessible
    run_test "devenv module options" "nix eval .#devenvModules.claude-code"
    
    # Test 2: home-manager module options are accessible  
    run_test "home-manager module options" "nix eval .#homeManagerModules.claude-code"
    
    # Test 3: Preset definitions are valid
    # run_test "preset definitions valid" "nix eval --impure --expr '
    #     let flake = builtins.getFlake (builtins.toString ./.);
    #         presets = import ./presets.nix { 
    #           lib = flake.inputs.nixpkgs.lib; 
    #           tools = {}; 
    #         };
    #     in builtins.attrNames presets
    # '"
}

# Test edge cases and error conditions
test_edge_cases() {
    log_info "=== Testing edge cases ==="
    
    pushd tests/fixtures/edge-case-test 2>&1 > /dev/null
    
    # Test 1: Invalid stdio config fails properly
    if nix develop --impure .#invalid-stdio --command echo loaded 2>/dev/null; then
        log_error "Invalid stdio config should fail but didn't"
    else
        log_success "Invalid stdio config properly rejected"
    fi
    
    # Test 2: Invalid sse config fails properly  
    if nix develop --impure .#invalid-sse --command echo loaded 2>/dev/null; then
        log_error "Invalid sse config should fail but didn't"
    else
        log_success "Invalid sse config properly rejected"
    fi
    
    # Cleanup will be handled by trap
    popd 2>&1 > /dev/null
}

# Main test execution
main() {
    log_info "Starting claude-code module integration tests..."
    echo
    
    # Clean up any existing test directories from previous runs
    log_info "Cleaning up any existing test directories..."
    
    # Run test suites
    test_devenv_module
    echo
    test_home_manager_module  
    echo
    test_module_options
    echo
    test_edge_cases
    echo
    
    # Print summary
    print_summary

    if [ $TESTS_FAILED -gt 0 ]; then
        echo
        echo -e "${RED}Failed tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  - $test"
        done
        echo
        exit 1
    else
        echo
        log_success "All tests passed!"
        exit 0
    fi
}

# Run main function
main "$@"

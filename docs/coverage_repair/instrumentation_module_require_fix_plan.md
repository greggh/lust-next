# Module Require Instrumentation Recursion Fix Plan

## Current Status and Issue

The coverage module's `instrument_require()` function currently suffers from a critical recursion issue that causes C stack overflows. Our previous implementation attempted to address this with:

1. Module tracking tables (`currently_instrumenting`, `instrumented_modules`)
2. Core module exclusion lists
3. Recursion depth tracking

However, these measures are insufficient for several reasons:

1. The instrumentation process itself triggers additional requires
2. The tracking code injected into modules causes more require calls
3. The filesystem operations during module lookup can cause recursion

Our current "solution" merely works around these issues by modifying the test case to avoid triggering the recursion, which is not a proper engineering approach.

## Technical Fix Plan

### 1. Isolation of Instrumentation Environment

**Problem**: Instrumentation calls trigger more requires which trigger more instrumentation.

**Solution**:
- Create an isolated sandbox for instrumentation execution
- Implement a non-recursive module loader for instrumented code
- Add clear boundaries between instrumentation and module execution environments

```lua
-- Example implementation
local function create_isolated_environment()
  local env = setmetatable({}, {__index = _G})
  env._G = env  -- Self-reference for _G
  
  -- Create a non-recursive require function
  env.require = function(module_name)
    -- Direct lookup in package.loaded without instrumentation
    -- ...
  end
  
  return env
end
```

### 2. Non-Recursive Module Path Resolution

**Problem**: File path resolution triggers fs module which triggers more requires.

**Solution**:
- Replace filesystem operations with direct Lua I/O operations
- Create a module path cache to avoid repeated lookups
- Implement direct file checking without additional requires

```lua
-- Example implementation
local function find_module_path_non_recursive(module_name)
  -- Check module_path_cache first
  -- Use direct io.open instead of fs.file_exists
  -- Store result in cache for future use
end
```

### 3. Static Tracking Code Generation

**Problem**: Dynamic tracking code generation causes require calls during module execution.

**Solution**:
- Generate tracking code that doesn't trigger further requires
- Use static imports at the beginning of instrumented modules
- Implement context passing to avoid dynamic path generation

```lua
-- Example instrumented module structure
local _coverage_track = require("lib.coverage").track_directly
local _file_path = "/absolute/path/to/module.lua"  -- Hardcoded during instrumentation

-- Then in instrumented code:
_coverage_track(_file_path, line_number)  -- Direct call with no dynamic requires
```

### 4. Boundary-Aware Testing Architecture

**Problem**: Tests create artificial conditions that break module boundaries.

**Solution**:
- Implement test environment isolation
- Create module tests that mimic real-world usage patterns
- Add clear instrumentation boundaries that respect module structure

```lua
-- Example test structure
local test_module_path = create_test_fixture()
local original_package_path = package.path

-- Setup proper module boundaries
package.path = build_isolated_path(test_module_path)

-- Load through instrumented require with proper boundary detection
local result = require("test_module")
```

### 5. Implementation and Testing Strategy

1. **Incremental Implementation**:
   - First implement the isolated environment for module execution
   - Then implement the non-recursive path resolution
   - Finally implement the static tracking code generation

2. **Test Verification**:
   - Create targeted test cases for each boundary issue
   - Test with real-world module patterns
   - Verify recursive modules work correctly
   - Measure stack depth to ensure no growth during nested requires

3. **Integration Plan**:
   - Update the `instrument_require()` function first
   - Then modify the tracking code generation in `instrument_file()`
   - Finally update tests to properly verify functionality

## Success Criteria

A successful implementation will:

1. Pass all tests including the original Test 4 without modifications
2. Handle nested module requires without stack growth
3. Work with circular dependencies (A requires B requires A)
4. Properly instrument real-world module patterns
5. Not require special-case handling for test modules

## Timeline and Resources

Estimated implementation time: 1 day (8 hours)

Key files to modify:
- `/lib/coverage/instrumentation.lua`: Core instrumentation logic
- `/run-instrumentation-tests.lua`: Test file with proper test cases

Dependencies:
- Clear understanding of Lua module loading process
- Knowledge of environment isolation techniques
- Expertise in recursive call prevention
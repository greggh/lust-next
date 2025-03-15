# Module Reset Utilities
This document describes the module management utilities provided by Firmo to help maintain clean test state.

## Overview
Firmo provides utilities for resetting and reloading modules between tests. These utilities help ensure that each test runs with a fresh module state, eliminating test cross-contamination.
There are two approaches to module reset in firmo:

1. **Individual Module Reset**: Reset specific modules manually within tests
2. **Automatic Test Suite Isolation**: Automatically reset all modules between test files

## Individual Module Reset Functions

### firmo.reset_module(module_name)
Resets and reloads a module, ensuring a fresh state.
**Parameters:**

- `module_name` (string): The name of the module to reset (as it would be used in require())
**Returns:**

- The freshly loaded module instance
**Example:**

```lua
describe("Database tests", function()
  local db
  before_each(function()
    -- Reset the module before each test
    db = firmo.reset_module("app.database")
  end)
  it("connects to the database", function()
    -- Each test gets a fresh instance of the module
    expect(db.connect()).to.be.truthy()
  end)
  it("performs queries", function()
    -- No state leakage from previous tests
    db.connect()
    expect(db.query("SELECT * FROM users")).to.exist()
  end)
end)

```text

### firmo.with_fresh_module(module_name, test_fn)
Runs a function with a freshly loaded module, simplifying single-use cases.
**Parameters:**

- `module_name` (string): The name of the module to reset and reload
- `test_fn` (function): Function to run with the fresh module (receives module as argument)
**Returns:**

- The result of the test_fn
**Example:**

```lua
it("executes a test with a fresh module", function()
  firmo.with_fresh_module("app.config", function(config)
    -- We have a guaranteed fresh config module
    expect(config.initialized).to.equal(false)
    -- Modify the module
    config.set("debug", true)
    -- Verify changes
    expect(config.get("debug")).to.equal(true)
  end)
  -- Any changes to the module are isolated to the with_fresh_module call
end)

```text

## Automatic Test Suite Isolation
Firmo provides an enhanced module reset system that automatically resets all modules between test files, ensuring complete isolation. This system is built into the run_all_tests.lua runner.

### Using the Module Reset System
The module reset system is automatically used by the run_all_tests.lua script when available. You can also use it directly:

```lua
local firmo = require("firmo")
local module_reset = require("lib.core.module_reset")
-- Register with firmo
module_reset.register_with_firmo(firmo)
-- Configure isolation options
module_reset.configure({
  reset_modules = true,  -- Enable/disable module reset
  verbose = false        -- Show detailed output about reset modules
})

```text

### Module Reset API

#### `module_reset.init()`
Initializes the module reset system by taking a snapshot of the current module state.

#### `module_reset.register_with_firmo(firmo)`
Registers the module reset system with firmo, enhancing the `reset()` method.

#### `module_reset.configure(options)`
Configures the module reset system:

```lua
module_reset.configure({
  reset_modules = true,  -- Enable/disable module reset
  verbose = false        -- Show detailed output about reset modules
})

```text

#### `module_reset.reset_all(options)`
Resets all non-protected modules:

```lua
local reset_count = module_reset.reset_all({
  verbose = false  -- Show detailed output about reset modules
})

```text

#### `module_reset.reset_pattern(pattern, options)`
Resets modules matching the given pattern:

```lua
local reset_count = module_reset.reset_pattern("my_module.*", {
  verbose = false
})

```text

#### `module_reset.protect(modules)`
Protects specified modules from being reset:

```lua
-- Protect a single module
module_reset.protect("important_module")
-- Protect multiple modules
module_reset.protect({"module1", "module2", "module3"})

```text

#### `module_reset.get_loaded_modules()`
Returns a list of currently loaded modules that are not protected.

#### `module_reset.get_memory_usage()`
Returns information about memory usage.

#### `module_reset.analyze_memory_usage(options)`
Analyzes memory usage by modules and returns a sorted list of modules by memory consumption.

### Running Tests with Module Reset
The built-in test runner automatically uses module reset if available:

```bash
lua run_all_tests.lua

```text
You can add flags to customize the runner:

```bash

# Verbose output including module resets
lua run_all_tests.lua --verbose

# Track memory usage during tests
lua run_all_tests.lua --memory

# Show performance statistics
lua run_all_tests.lua --performance

# Filter tests by pattern
lua run_all_tests.lua --filter "database_*"

```text

## Best Practices

### When to Use Module Reset

1. **Tests that modify global module state**: If your tests change the state of a module in ways that could affect other tests
2. **Database or resource tests**: When testing modules that connect to databases or external resources
3. **Configuration-dependent tests**: When testing with different configurations
4. **Before/After hooks**: Use reset_module in before_each for thorough isolation

### Example: Database Testing Pattern

```lua
describe("User database operations", function()
  local db
  local user_service
  before_each(function()
    -- Reset both modules to ensure a clean state
    db = firmo.reset_module("app.database")
    user_service = firmo.reset_module("app.services.user")
    -- Now set up fresh state
    db.connect({
      type = "sqlite",
      in_memory = true  -- Use in-memory DB for tests
    })
    -- Create test data
    db.execute("CREATE TABLE users (id INTEGER, name TEXT)")
    db.execute("INSERT INTO users VALUES (1, 'Test User')")
  end)
  after_each(function()
    -- Clean up resources
    db.disconnect()
  end)
  it("finds a user by id", function()
    local user = user_service.find_by_id(1)
    expect(user).to.exist()
    expect(user.name).to.equal("Test User")
  end)
  it("creates a new user", function()
    local new_user = user_service.create({name = "New User"})
    expect(new_user.id).to.exist()
    expect(new_user.name).to.equal("New User")
    -- Verify the user was saved
    local found = user_service.find_by_id(new_user.id)
    expect(found).to.exist()
    expect(found.name).to.equal("New User")
  end)
end)

```text

### Handling Complex Dependencies
For modules with complex dependency graphs, use reset_module on the highest-level module that needs to be reset:

```lua
describe("Authentication service", function()
  -- Reset the main service which transitively requires other modules
  local auth_service
  before_each(function()
    -- This will effectively reset all dependencies too, since they'll be re-required
    auth_service = firmo.reset_module("app.services.auth")
  end)
  it("authenticates valid credentials", function()
    expect(auth_service.authenticate("user", "password")).to.be.truthy()
  end)
end)

```text

### Using Both Approaches Together
For maximum isolation, you can use both approaches:

1. Use the automatic test suite isolation to reset modules between test files
2. Use individual module reset within tests for modules that need to be reset between test cases

```lua
-- In your test runner, enable automatic test suite isolation
local module_reset = require("lib.core.module_reset")
module_reset.register_with_firmo(firmo)
module_reset.configure({ reset_modules = true })
-- In your tests, reset specific modules that need per-test isolation
describe("User service tests", function()
  local user_service
  before_each(function()
    -- Reset for each test case
    user_service = firmo.reset_module("app.services.user")
  end)

  -- Tests...
end)

```text

## Implementation Notes
The basic module reset utilities work by:

1. Clearing the module from Lua's `package.loaded` table
2. Calling `require()` to reload the module
3. Returning the freshly loaded module instance
The enhanced automatic module reset system extends this functionality to track all loaded modules and provide more powerful reset capabilities, memory tracking, and performance analysis.


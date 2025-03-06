# Module Reset Utilities

This document describes the module management utilities provided by Lust-Next to help maintain clean test state.

## Overview

Lust-Next provides utilities for resetting and reloading modules between tests. These utilities help ensure that each test runs with a fresh module state, eliminating test cross-contamination.

## Module Reset Functions

### lust.reset_module(module_name)

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
    db = lust.reset_module("app.database")
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
```

### lust.with_fresh_module(module_name, test_fn)

Runs a function with a freshly loaded module, simplifying single-use cases.

**Parameters:**
- `module_name` (string): The name of the module to reset and reload
- `test_fn` (function): Function to run with the fresh module (receives module as argument)

**Returns:**
- The result of the test_fn

**Example:**
```lua
it("executes a test with a fresh module", function()
  lust.with_fresh_module("app.config", function(config)
    -- We have a guaranteed fresh config module
    expect(config.initialized).to.equal(false)
    
    -- Modify the module
    config.set("debug", true)
    
    -- Verify changes
    expect(config.get("debug")).to.equal(true)
  end)
  
  -- Any changes to the module are isolated to the with_fresh_module call
end)
```

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
    db = lust.reset_module("app.database")
    user_service = lust.reset_module("app.services.user")
    
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
```

### Handling Complex Dependencies

For modules with complex dependency graphs, use reset_module on the highest-level module that needs to be reset:

```lua
describe("Authentication service", function()
  -- Reset the main service which transitively requires other modules
  local auth_service
  
  before_each(function()
    -- This will effectively reset all dependencies too, since they'll be re-required
    auth_service = lust.reset_module("app.services.auth")
  end)
  
  it("authenticates valid credentials", function()
    expect(auth_service.authenticate("user", "password")).to.be.truthy()
  end)
end)
```

## Implementation Notes

The module reset utilities work by:

1. Clearing the module from Lua's `package.loaded` table
2. Calling `require()` to reload the module
3. Returning the freshly loaded module instance

This ensures all state within the module is reset to its initial values.
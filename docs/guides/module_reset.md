# Module Reset Guide

## Test Setup
```lua
describe("Module Tests", function()
  before(function()
    -- Reset modules before each test
  end)
  
  after(function()
    -- Clean up after each test
  end)
end)
```

## Best Practices

1. Reset modules only when needed
2. Use before hook for setup
3. Clean up in after hook

## Example Usage

```lua
describe("Database Module", function()
  local db
  
  before(function()
    -- Get fresh database module
    db = firmo.reset_module("app.database")
    db.connect()
  end)
  
  after(function()
    -- Clean up
    db.disconnect()
  end)
  
  it("creates records", function()
    db.create({id = 1})
    expect(db.count()).to.equal(1)
  end)
end)
```

## Database Example

```lua
describe("Database Operations", function()
  local db
  
  before(function()
    -- Fresh database module for each test
    db = firmo.reset_module("app.database")
    db.connect({in_memory = true})
  end)
  
  after(function()
    -- Clean up after each test
    db.disconnect()
  end)
  
  it("creates records", function()
    db.create({id = 1})
    expect(db.count()).to.equal(1)
  end)
  
  it("starts empty", function()
    -- Previous test's records are gone
    expect(db.count()).to.equal(0)
  end)
end)
```

## Configuration Example

```lua
describe("Config-dependent Module", function()
  local config
  local app
  
  before(function()
    -- Reset both modules before each test
    config = firmo.reset_module("app.config")
    app = firmo.reset_module("app.core")
  end)
  
  it("works in development", function()
    config.set_env("development")
    app.init()
    expect(app.debug).to.be_truthy()
  end)
  
  it("works in production", function()
    config.set_env("production")
    app.init()
    expect(app.debug).to_not.be_truthy()
  end)
end)
```

## Best Practices

1. Reset modules in before hook when they need fresh state
2. Clean up resources in after hook
3. Reset dependent modules together
4. Use in-memory/mock resources when possible

## Advanced Usage

### Protected Modules

Some modules should not be reset:

```lua
-- In test setup
module_reset.protect({
  "app.logger",
  "app.constants"
})
```

### Pattern Reset

Reset modules matching a pattern:

```lua
-- Reset all service modules
module_reset.reset_pattern("app%.services%.")
```

### Memory Usage

Track memory usage:

```lua
describe("Memory Test", function()
  it("doesn't leak", function()
    local before = module_reset.get_memory_usage()
    
    local module = firmo.reset_module("app.heavy")
    module.process()
    
    collectgarbage("collect")
    local after = module_reset.get_memory_usage()
    
    expect(after).to.be_less_than(before * 1.1)
  end)
end)
```

## Summary

- Use before hook to reset modules that need fresh state
- Use after hook to clean up resources
- Reset dependent modules together
- Protect modules that should maintain state
- Monitor memory usage when needed
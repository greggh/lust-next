# Module Reset Examples

This document provides practical examples of using firmo's module reset functionality in different testing scenarios.

> **Note**: This file contains comprehensive code examples for documentation purposes. For a simple executable demonstration, see `examples/module_reset_example.lua` which can be run directly to see basic module reset functionality in action.

## Basic Module Reset Examples

### Example 1: Manual Module Reset

This example demonstrates manual module reset for a simple counter module:

```lua
-- counter.lua
local counter = {}
counter.value = 0

function counter.increment()
  counter.value = counter.value + 1
  return counter.value
end

function counter.reset()
  counter.value = 0
end

return counter
```

Test file:

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("Counter module tests with reset", function()
  local counter

  before_each(function()
    -- Reset the counter module before each test
    counter = firmo.reset_module("counter")
    expect(counter.value).to.equal(0)
  end)

  it("increments from zero", function()
    expect(counter.increment()).to.equal(1)
    expect(counter.value).to.equal(1)
  end)

  it("also increments from zero", function()
    -- Thanks to module reset, we start at 0 again
    expect(counter.increment()).to.equal(1)
    expect(counter.increment()).to.equal(2)
    expect(counter.value).to.equal(2)
  end)
end)
```

### Example 2: Using with_fresh_module

This example shows how to use `with_fresh_module` for temporary module isolation:

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Counter module with temporary isolation", function()
  it("isolates changes within with_fresh_module", function()
    -- Load the counter module normally first
    local counter = require("counter")
    counter.value = 5  -- Set an initial value
    
    -- Use the module with temporary isolation
    firmo.with_fresh_module("counter", function(fresh_counter)
      -- Inside this function we have a fresh counter module
      expect(fresh_counter.value).to.equal(0)
      fresh_counter.increment()
      expect(fresh_counter.value).to.equal(1)
    end)
    
    -- Outside the function, we have the original module
    expect(counter.value).to.equal(5)
  end)
  
  it("can be used multiple times", function()
    firmo.with_fresh_module("counter", function(counter)
      expect(counter.value).to.equal(0)
      counter.value = 10
    end)
    
    firmo.with_fresh_module("counter", function(counter)
      -- Each call gets a fresh module
      expect(counter.value).to.equal(0)
    end)
  end)
end)
```

## Enhanced Module Reset System Examples

### Example 3: Setting Up the Enhanced System

This example demonstrates setting up the enhanced module reset system:

```lua
local firmo = require("firmo")
local module_reset = require("lib.core.module_reset")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Register with firmo
module_reset.register_with_firmo(firmo)

-- Configure isolation options
module_reset.configure({
  reset_modules = true,  -- Enable automatic reset between test files
  verbose = false        -- Don't show detailed output
})

describe("Module reset system basics", function()
  it("is registered with firmo", function()
    expect(firmo.module_reset).to.exist()
    expect(firmo.module_reset.reset_all).to.be.a("function")
  end)
  
  it("can reset all modules", function()
    -- Load the counter module
    local counter = require("counter")
    counter.value = 42
    
    -- Reset all non-protected modules
    local count = module_reset.reset_all()
    
    -- Verify the counter module was reset
    local fresh_counter = require("counter")
    expect(fresh_counter.value).to.equal(0)
    expect(count).to.be_greater_than(0)
  end)
end)
```

### Example 4: Resetting Modules by Pattern

This example shows how to selectively reset modules by pattern:

```lua
local firmo = require("firmo")
local module_reset = require("lib.core.module_reset")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Selective module reset", function()
  before_each(function()
    -- Make sure module_reset is initialized
    module_reset.init()
  end)
  
  it("resets modules matching a pattern", function()
    -- Create and modify multiple modules in the same namespace
    local counter1 = require("app.counters.counter1")
    local counter2 = require("app.counters.counter2")
    local other_module = require("app.other_module")
    
    counter1.value = 10
    counter2.value = 20
    other_module.value = 30
    
    -- Reset only the counter modules
    local reset_count = module_reset.reset_pattern("app%.counters%.")
    
    -- Verify only counter modules were reset
    expect(reset_count).to.equal(2)
    
    local fresh_counter1 = require("app.counters.counter1")
    local fresh_counter2 = require("app.counters.counter2")
    local same_other_module = require("app.other_module")
    
    expect(fresh_counter1.value).to.equal(0)
    expect(fresh_counter2.value).to.equal(0)
    expect(same_other_module.value).to.equal(30)  -- Not reset
  end)
end)
```

### Example 5: Protecting Essential Modules

This example demonstrates protecting modules from being reset:

```lua
local firmo = require("firmo")
local module_reset = require("lib.core.module_reset")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Module protection", function()
  before_each(function()
    -- Initialize module_reset with a clean slate for this test
    module_reset.init()
  end)
  
  it("protects specified modules from reset", function()
    -- Load and modify modules
    local counter = require("counter")
    local essential = require("app.essential_module")
    
    counter.value = 10
    essential.value = 20
    
    -- Protect the essential module
    module_reset.protect("app.essential_module")
    
    -- Reset all modules
    module_reset.reset_all()
    
    -- Verify the counter was reset but essential module wasn't
    local fresh_counter = require("counter")
    local same_essential = require("app.essential_module")
    
    expect(fresh_counter.value).to.equal(0)   -- Reset
    expect(same_essential.value).to.equal(20) -- Not reset
  end)
  
  it("can protect multiple modules at once", function()
    -- Protect multiple modules
    module_reset.protect({
      "app.config",
      "app.logger",
      "app.constants"
    })
    
    -- Verify they're protected
    expect(module_reset.is_protected("app.config")).to.be_truthy()
    expect(module_reset.is_protected("app.logger")).to.be_truthy()
    expect(module_reset.is_protected("app.constants")).to.be_truthy()
    expect(module_reset.is_protected("app.not_protected")).to_not.be_truthy()
  end)
end)
```

## Real-World Testing Patterns

### Example 6: Database Testing Pattern

This example demonstrates module reset with database testing:

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("User repository tests", function()
  local db
  local user_repo
  
  before_each(function()
    -- Reset both modules to ensure clean state
    db = firmo.reset_module("app.database")
    user_repo = firmo.reset_module("app.repositories.user")
    
    -- Set up in-memory test database
    db.connect({
      driver = "sqlite",
      database = ":memory:"
    })
    
    -- Create test schema
    db.execute([[
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        username TEXT NOT NULL,
        email TEXT NOT NULL
      )
    ]])
  end)
  
  after_each(function()
    -- Clean up resources
    db.disconnect()
  end)
  
  it("creates a new user", function()
    local user = user_repo.create({
      username = "testuser",
      email = "test@example.com"
    })
    
    expect(user.id).to.exist()
    expect(user.username).to.equal("testuser")
    
    -- Verify in database
    local found = user_repo.find_by_id(user.id)
    expect(found).to.exist()
    expect(found.email).to.equal("test@example.com")
  end)
  
  it("finds users by username", function()
    -- Setup test data
    user_repo.create({
      username = "user1",
      email = "user1@example.com"
    })
    user_repo.create({
      username = "user2",
      email = "user2@example.com"
    })
    
    -- Find by username
    local user = user_repo.find_by_username("user2")
    expect(user).to.exist()
    expect(user.email).to.equal("user2@example.com")
  end)
  
  it("updates a user", function()
    -- Create test user
    local user = user_repo.create({
      username = "updateme",
      email = "old@example.com"
    })
    
    -- Update user
    local updated = user_repo.update(user.id, {
      email = "new@example.com"
    })
    
    expect(updated).to.exist()
    expect(updated.email).to.equal("new@example.com")
    expect(updated.username).to.equal("updateme") -- Unchanged
    
    -- Verify in database
    local found = user_repo.find_by_id(user.id)
    expect(found.email).to.equal("new@example.com")
  end)
end)
```

### Example 7: Configuration Testing Pattern

This example demonstrates testing different configurations using module reset:

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before = firmo.before

describe("Application with different environments", function()
  local config
  local app
  
  before_each(function()
    -- Reset both modules for each test
    config = firmo.reset_module("app.config")
    app = firmo.reset_module("app.core")
  end)
  
  it("loads development settings", function()
    -- Set up development environment
    config.set_environment("development")
    app.initialize()
    
    expect(app.environment).to.equal("development")
    expect(app.debug).to.be_truthy()
    expect(app.log_level).to.equal("debug")
    expect(app.database_config.host).to.equal("localhost")
  end)
  
  it("loads production settings", function()
    -- Set up production environment
    config.set_environment("production")
    app.initialize()
    
    expect(app.environment).to.equal("production")
    expect(app.debug).to_not.be_truthy()
    expect(app.log_level).to.equal("warning")
    expect(app.database_config.host).to.equal("db.production.example.com")
  end)
  
  it("loads test settings", function()
    -- Set up test environment
    config.set_environment("test")
    app.initialize()
    
    expect(app.environment).to.equal("test")
    expect(app.debug).to.be_truthy()
    expect(app.log_level).to.equal("debug")
    expect(app.database_config.host).to.equal("localhost")
    expect(app.database_config.database).to.equal(":memory:") -- In-memory DB for tests
  end)
end)
```

### Example 8: Memory Analysis Pattern

This example demonstrates using the memory analysis capabilities:

```lua
local firmo = require("firmo")
local module_reset = require("lib.core.module_reset")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Memory usage analysis", function()
  it("tracks memory usage of modules", function()
    -- Create a module with significant memory use
    local memory_module_content = [[
      local heavy_module = {}
      heavy_module.data = {}
      
      -- Allocate some memory
      for i = 1, 1000 do
        heavy_module.data[i] = string.rep("memory", 100)
      end
      
      return heavy_module
    ]]
    
    -- Write module to a temporary file
    local fs = require("lib.tools.filesystem")
    local temp_file = os.tmpname()
    local success = fs.write_file(temp_file, memory_module_content)
    expect(success).to.be_truthy()
    
    -- Load the module
    local heavy_module = dofile(temp_file)
    expect(heavy_module).to.exist()
    expect(heavy_module.data).to.exist()
    
    -- Get memory usage
    local memory_usage = module_reset.get_memory_usage()
    expect(memory_usage.current).to.exist()
    expect(memory_usage.current).to.be_greater_than(0)
    
    -- Analyze memory usage by module
    local module_memory = module_reset.analyze_memory_usage()
    expect(module_memory).to.be.a("table")
    
    -- We can't make specific assertions about memory values
    -- as they vary by environment, but we can check the structure
    if #module_memory > 0 then
      local first_entry = module_memory[1]
      expect(first_entry.name).to.exist()
      expect(first_entry.memory).to.exist()
      expect(first_entry.memory).to.be_greater_than(0)
    end
    
    -- Clean up
    os.remove(temp_file)
  end)
end)
```

### Example 9: Enhanced Module Reset in Test Runner

This example shows how to integrate module reset into a test runner:

```lua
-- test_runner.lua
local firmo = require("firmo")
local module_reset = require("lib.core.module_reset")
local fs = require("lib.tools.filesystem")

-- Function to discover test files
local function find_test_files(directory)
  local files = fs.get_directory_contents(directory, true) -- recursive
  local test_files = {}
  
  for _, path in ipairs(files) do
    if path:match("_test%.lua$") then
      table.insert(test_files, path)
    end
  end
  
  return test_files
end

-- Initialize the module reset system
module_reset.register_with_firmo(firmo)
module_reset.configure({
  reset_modules = true,
  verbose = os.getenv("VERBOSE") == "1"
})

-- Parse command-line arguments
local args = {...}
local test_dir = args[1] or "tests"
local pattern = args[2]

-- Find test files
local test_files = find_test_files(test_dir)
local filtered_files = {}

-- Apply pattern filter if provided
if pattern then
  for _, file in ipairs(test_files) do
    if file:match(pattern) then
      table.insert(filtered_files, file)
    end
  end
else
  filtered_files = test_files
end

print("Running " .. #filtered_files .. " test files")

-- Run tests with module reset between files
local passed = 0
local failed = 0

for i, file in ipairs(filtered_files) do
  print(string.format("\n[%d/%d] Running %s", i, #filtered_files, file))
  
  -- Run the test file
  local success = firmo.run_file(file)
  
  if success then
    passed = passed + 1
  else
    failed = failed + 1
  end
  
  -- Reset modules between files
  local reset_count = module_reset.reset_all()
  
  if os.getenv("VERBOSE") == "1" then
    print("Reset " .. reset_count .. " modules")
  end
  
  -- Force garbage collection
  collectgarbage("collect")
end

print(string.format("\nTest Summary: %d passed, %d failed", passed, failed))

-- Return success status
return failed == 0
```

## Module Reset with External Resources

### Example 10: File System Testing Pattern

This example demonstrates testing code that interacts with the file system:

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local fs = require("lib.tools.filesystem")

describe("File manager tests", function()
  local file_manager
  local temp_dir
  
  before_each(function()
    -- Reset the file manager module
    file_manager = firmo.reset_module("app.file_manager")
    
    -- Create a temporary directory for tests
    temp_dir = os.tmpname()
    os.remove(temp_dir) -- tmpname creates a file, we need a directory
    fs.create_directory(temp_dir)
    
    -- Initialize the file manager with our test directory
    file_manager.init(temp_dir)
  end)
  
  after_each(function()
    -- Clean up test directory
    fs.remove_directory(temp_dir, true) -- recursive
  end)
  
  it("creates a file", function()
    local file_path = file_manager.create_file("test.txt", "Hello, world")
    
    -- Verify file exists
    expect(fs.file_exists(file_path)).to.be_truthy()
    
    -- Verify content
    local content = fs.read_file(file_path)
    expect(content).to.equal("Hello, world")
  end)
  
  it("lists files in directory", function()
    -- Create test files
    file_manager.create_file("file1.txt", "Content 1")
    file_manager.create_file("file2.txt", "Content 2")
    file_manager.create_file("other.dat", "Binary data")
    
    -- List all files
    local all_files = file_manager.list_files()
    expect(#all_files).to.equal(3)
    
    -- List by pattern
    local text_files = file_manager.list_files("%.txt$")
    expect(#text_files).to.equal(2)
  end)
end)
```

### Example 11: API Client Testing Pattern

This example demonstrates testing HTTP API clients with module reset:

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before = firmo.before

describe("API client tests", function()
  local api_client
  local mock_http
  
  before_each(function()
    -- Reset both the API client and mock HTTP module
    api_client = firmo.reset_module("app.api_client")
    mock_http = firmo.reset_module("lib.tools.mock_http")
    
    -- Configure the API client to use our mock HTTP module
    api_client.configure({
      base_url = "https://api.example.com",
      http_client = mock_http,
      timeout = 5
    })
  end)
  
  it("fetches user data", function()
    -- Set up mock response
    mock_http.mock_response({
      status = 200,
      body = [[{"id": 123, "name": "Test User", "email": "test@example.com"}]],
      headers = {["Content-Type"] = "application/json"}
    })
    
    -- Call the API
    local user, err = api_client.get_user(123)
    
    -- Verify the request
    local last_request = mock_http.get_last_request()
    expect(last_request.url).to.equal("https://api.example.com/users/123")
    expect(last_request.method).to.equal("GET")
    
    -- Verify the response handling
    expect(err).to_not.exist()
    expect(user).to.exist()
    expect(user.id).to.equal(123)
    expect(user.name).to.equal("Test User")
    expect(user.email).to.equal("test@example.com")
  end)
  
  it("handles API errors", function()
    -- Set up error response
    mock_http.mock_response({
      status = 404,
      body = [[{"error": "User not found"}]],
      headers = {["Content-Type"] = "application/json"}
    })
    
    -- Call the API
    local user, err = api_client.get_user(999)
    
    -- Verify error handling
    expect(user).to_not.exist()
    expect(err).to.exist()
    expect(err.code).to.equal(404)
    expect(err.message).to.equal("User not found")
  end)
end)
```

## Conclusion

These examples demonstrate how to use firmo's module reset functionality in various testing scenarios. The module reset system helps ensure test isolation, prevent state leakage between tests, and create more robust test suites.

For more detailed information, refer to:

- [Module Reset API Documentation](../docs/api/module_reset.md)
- [Module Reset Guide](../docs/guides/module_reset.md)
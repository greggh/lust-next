# Focus Mode Examples

This document provides practical examples of using Firmo's focus and exclude features for controlling test execution.

## Basic Focus Examples

### Focusing a Single Test

```lua
-- focus_single_test.lua
local firmo = require("firmo")
local describe, it, fit, expect = firmo.describe, firmo.it, firmo.fit, firmo.expect

describe("Calculator", function()
  it("adds numbers", function()
    expect(2 + 2).to.equal(4)
  end)
  
  fit("subtracts numbers", function()
    expect(5 - 3).to.equal(2)
  end)
  
  it("multiplies numbers", function()
    expect(2 * 3).to.equal(6)
  end)
end)
```

When executed:
```
$ lua test.lua examples/focus_single_test.lua

Calculator
  SKIP (not focused) adds numbers
  ✓ subtracts numbers
  SKIP (not focused) multiplies numbers

Running 1 test complete (2 skipped)
✓ 1 passed, 0 failed
```

### Focusing a Test Group

```lua
-- focus_test_group.lua
local firmo = require("firmo")
local describe, fdescribe, it, expect = firmo.describe, firmo.fdescribe, firmo.it, firmo.expect

describe("Calculator", function()
  it("adds numbers", function()
    expect(2 + 2).to.equal(4)
  end)
end)

fdescribe("String Utilities", function()
  it("concatenates strings", function()
    expect("hello" .. " " .. "world").to.equal("hello world")
  end)
  
  it("trims whitespace", function()
    expect(string.match("  test  ", "%S.*%S")).to.equal("test")
  end)
end)

describe("Array Functions", function()
  it("sorts arrays", function()
    local arr = {3, 1, 2}
    table.sort(arr)
    expect(arr[1]).to.equal(1)
  end)
end)
```

When executed:
```
$ lua test.lua examples/focus_test_group.lua

Calculator
  SKIP (not focused) adds numbers

String Utilities
  ✓ concatenates strings
  ✓ trims whitespace

Array Functions
  SKIP (not focused) sorts arrays

Running 2 tests complete (2 skipped)
✓ 2 passed, 0 failed
```

## Nested Focus Examples

### Focused Tests in Nested Groups

```lua
-- focus_nested.lua
local firmo = require("firmo")
local describe, fdescribe, it, fit, expect = firmo.describe, firmo.fdescribe, firmo.it, firmo.fit, firmo.expect

describe("User System", function()
  describe("Authentication", function()
    it("logs in valid users", function()
      expect(true).to.be.truthy()
    end)
    
    fit("rejects invalid passwords", function()
      expect(false).to.be_falsy()
    end)
  end)
  
  fdescribe("Authorization", function()
    it("checks user permissions", function()
      expect(true).to.be.truthy()
    end)
    
    it("grants access to resources", function()
      expect({1, 2, 3}).to.have_length(3)
    end)
  end)
  
  describe("Profile", function()
    it("updates user information", function()
      expect("name").to.be.a("string")
    end)
  end)
end)
```

When executed:
```
$ lua test.lua examples/focus_nested.lua

User System
  Authentication
    SKIP (not focused) logs in valid users
    ✓ rejects invalid passwords
  Authorization
    ✓ checks user permissions
    ✓ grants access to resources
  Profile
    SKIP (not focused) updates user information

Running 3 tests complete (2 skipped)
✓ 3 passed, 0 failed
```

## Exclude Examples

### Excluding Individual Tests

```lua
-- exclude_tests.lua
local firmo = require("firmo")
local describe, it, xit, expect = firmo.describe, firmo.it, firmo.xit, firmo.expect

describe("File Operations", function()
  it("reads file content", function()
    expect("test").to.be.a("string")
  end)
  
  xit("writes to file", function()
    -- This would create a temporary file
    -- Skipped because we don't want to create files during regular tests
    error("This should never run!")
  end)
  
  it("checks if file exists", function()
    expect(true).to.be.truthy()
  end)
end)
```

When executed:
```
$ lua test.lua examples/exclude_tests.lua

File Operations
  ✓ reads file content
  SKIP writes to file
  ✓ checks if file exists

Running 2 tests complete (1 skipped)
✓ 2 passed, 0 failed
```

### Excluding Test Groups

```lua
-- exclude_groups.lua
local firmo = require("firmo")
local describe, xdescribe, it, expect = firmo.describe, firmo.xdescribe, firmo.it, firmo.expect

describe("Fast Tests", function()
  it("runs quickly", function()
    expect(1).to.equal(1)
  end)
end)

xdescribe("Slow Network Tests", function()
  it("connects to external API", function()
    -- This would make a network request
    error("This test should be skipped!")
  end)
  
  it("downloads large file", function()
    -- This would download a file
    error("This test should be skipped!")
  end)
end)

describe("More Fast Tests", function()
  it("calculates value", function()
    expect(1 + 1).to.equal(2)
  end)
end)
```

When executed:
```
$ lua test.lua examples/exclude_groups.lua

Fast Tests
  ✓ runs quickly

Slow Network Tests
  SKIP connects to external API
  SKIP downloads large file

More Fast Tests
  ✓ calculates value

Running 2 tests complete (2 skipped)
✓ 2 passed, 0 failed
```

## Mixed Focus and Exclude Examples

### Focus and Exclude Interaction

```lua
-- focus_exclude_interaction.lua
local firmo = require("firmo")
local describe, fdescribe, xdescribe, it, fit, xit, expect = 
  firmo.describe, firmo.fdescribe, firmo.xdescribe, firmo.it, firmo.fit, firmo.xit, firmo.expect

describe("Regular Group", function()
  it("normal test", function()
    expect(true).to.be.truthy()
  end)
  
  fit("focused test", function()
    expect(42).to.be.a("number")
  end)
  
  xit("excluded test", function()
    error("Should not run!")
  end)
end)

fdescribe("Focused Group", function()
  it("test in focused group", function()
    expect("test").to.be.a("string")
  end)
  
  xit("excluded test in focused group", function()
    error("Should not run despite focused parent!")
  end)
  
  fit("focused test in focused group", function()
    expect({}).to.be.a("table")
  end)
end)

xdescribe("Excluded Group", function()
  it("test in excluded group", function()
    error("Should not run!")
  end)
  
  fit("focused test in excluded group", function()
    error("Should not run despite being focused!")
  end)
end)
```

When executed:
```
$ lua test.lua examples/focus_exclude_interaction.lua

Regular Group
  SKIP (not focused) normal test
  ✓ focused test
  SKIP excluded test

Focused Group
  ✓ test in focused group
  SKIP excluded test in focused group
  ✓ focused test in focused group

Excluded Group
  SKIP test in excluded group
  SKIP focused test in excluded group

Running 3 tests complete (5 skipped)
✓ 3 passed, 0 failed
```

## Practical Debugging Example

### Isolating a Bug with Focus

```lua
-- debug_with_focus.lua
local firmo = require("firmo")
local describe, it, fit, expect = firmo.describe, firmo.it, firmo.fit, firmo.expect

-- Sample function with a bug
local function process_data(data)
  if type(data) ~= "table" then
    return nil, "Expected a table"
  end
  
  local result = {}
  for i, value in ipairs(data) do
    if type(value) == "number" then
      -- BUG: Should be adding to result[i] instead of result[value]
      result[value] = value * 2
    end
  end
  
  return result
end

describe("Data Processor", function()
  it("handles empty data", function()
    local result = process_data({})
    expect(result).to.be.a("table")
    expect(next(result)).to.equal(nil) -- table is empty
  end)
  
  it("processes strings", function()
    local result, err = process_data("invalid")
    expect(result).to.equal(nil)
    expect(err).to.equal("Expected a table")
  end)
  
  -- Focus on the failing test when debugging
  fit("processes numbers correctly", function()
    local data = {1, 2, 3}
    local result = process_data(data)
    
    -- This would fail because of the bug
    expect(result[1]).to.equal(2)
    expect(result[2]).to.equal(4)
    expect(result[3]).to.equal(6)
    
    -- Debugging output
    print("\nDebugging result table:")
    for k, v in pairs(result) do
      print(string.format("result[%s] = %s", tostring(k), tostring(v)))
    end
  end)
end)
```

## Test Development Workflow Example

```lua
-- incremental_development.lua
local firmo = require("firmo")
local describe, fdescribe, it, fit, xit, expect = 
  firmo.describe, firmo.fdescribe, firmo.it, firmo.fit, firmo.xit, firmo.expect

-- Feature under development: user validator
local function validate_user(user)
  if type(user) ~= "table" then
    return false, "User must be a table"
  end
  
  if type(user.name) ~= "string" or #user.name < 2 then
    return false, "Name must be a string with at least 2 characters"
  end
  
  if user.age and type(user.age) ~= "number" then
    return false, "Age must be a number if provided"
  end
  
  -- Email validation not implemented yet
  if user.email then
    -- TODO: Implement email validation
  end
  
  return true
end

-- Focus on the module we're developing
fdescribe("User Validator", function()
  -- Tests we've already completed
  it("rejects non-table input", function()
    local valid, error = validate_user("not a table")
    expect(valid).to.equal(false)
    expect(error).to.match("must be a table")
  end)
  
  it("requires valid name", function()
    local valid, error = validate_user({name = ""})
    expect(valid).to.equal(false)
    expect(error).to.match("at least 2 characters")
    
    valid = validate_user({name = "Jo"})
    expect(valid).to.equal(true)
  end)
  
  -- The test we're currently implementing
  fit("validates age when provided", function()
    local valid, error = validate_user({name = "Jo", age = "twenty"})
    expect(valid).to.equal(false)
    expect(error).to.match("Age must be a number")
    
    valid = validate_user({name = "Jo", age = 25})
    expect(valid).to.equal(true)
  end)
  
  -- Test for functionality we haven't implemented yet
  xit("validates email format", function()
    local valid, error = validate_user({name = "Jo", email = "not-an-email"})
    expect(valid).to.equal(false)
    expect(error).to.match("valid email")
    
    valid = validate_user({name = "Jo", email = "jo@example.com"})
    expect(valid).to.equal(true)
  end)
end)
```

## Using Focus with Tags

```lua
-- focus_with_tags.lua
local firmo = require("firmo")
local describe, fdescribe, it, fit, expect = 
  firmo.describe, firmo.fdescribe, firmo.it, firmo.fit, firmo.expect

-- Unit tests with a focused test
describe("Calculator", {tags = {"unit"}}, function()
  it("adds numbers", function()
    expect(2 + 2).to.equal(4)
  end)
  
  fit("subtracts numbers", function()
    expect(5 - 3).to.equal(2)
  end)
end)

-- Integration tests with a focused group
fdescribe("API Client", {tags = {"integration"}}, function()
  it("fetches data", function()
    -- Pretend API call
    expect(true).to.equal(true)
  end)
  
  it("sends updates", function()
    -- Pretend API call
    expect(true).to.equal(true)
  end)
end)
```

When executed with tags:
```
$ lua test.lua --tags=unit examples/focus_with_tags.lua

Calculator
  SKIP (not focused) adds numbers
  ✓ subtracts numbers

Running 1 test complete (1 skipped)
✓ 1 passed, 0 failed

$ lua test.lua --tags=integration examples/focus_with_tags.lua

API Client
  ✓ fetches data
  ✓ sends updates

Running 2 tests complete (0 skipped)
✓ 2 passed, 0 failed
```

## Conclusion

These examples demonstrate the versatility of Firmo's focus and exclude features for various testing scenarios. Remember that focus and exclude are primarily development tools - they should be used judiciously and removed before committing code to ensure all tests run properly in continuous integration environments.

The focus system is particularly valuable when:

1. You're developing new features and want to test incrementally
2. You're debugging a particular test failure
3. You need to temporarily skip problematic tests
4. You want to run a small subset of a large test suite for speed

When used properly, these tools can significantly improve your testing workflow and productivity.
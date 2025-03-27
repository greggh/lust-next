# Test Filtering Examples

This document provides practical examples of using Firmo's test filtering capabilities through tags and pattern matching.

## Basic Tag Examples

### Simple Test Tagging

```lua
-- tagging_basic.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Calculator", function()
  -- Tag for unit tests
  firmo.tags("unit")
  
  it("adds two numbers", function()
    expect(1 + 1).to.equal(2)
  end)
  
  it("subtracts two numbers", function()
    expect(5 - 3).to.equal(2)
  end)
  
  -- Add more specific tags for certain tests
  firmo.tags("math", "division")
  it("divides two numbers", function()
    expect(10 / 2).to.equal(5)
  end)
  
  -- Reset to just unit tag for remaining tests
  firmo.tags("unit")
  it("multiplies two numbers", function()
    expect(2 * 3).to.equal(6)
  end)
end)

describe("String Utils", function()
  -- Different tag for different component
  firmo.tags("unit", "strings")
  
  it("concatenates strings", function()
    expect("hello" .. " world").to.equal("hello world")
  end)
  
  it("converts to uppercase", function()
    expect(string.upper("hello")).to.equal("HELLO")
  end)
end)
```

Running with tags:
```bash
# Run all unit tests
lua test.lua --tags unit tagging_basic.lua

# Run only string-related tests
lua test.lua --tags strings tagging_basic.lua

# Run only division tests
lua test.lua --tags division tagging_basic.lua
```

### Hierarchical Tag Application

```lua
-- tagging_hierarchy.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Apply global tag to all tests in file
firmo.tags("api")

describe("User API", function()
  -- Apply module tag
  firmo.tags("user")
  
  it("retrieves user profile", function()
    expect(true).to.be.truthy()
  end)
  
  describe("Authentication", function()
    -- Apply feature tag
    firmo.tags("auth")
    
    it("logs in with valid credentials", function()
      expect(true).to.be.truthy()
    end)
    
    it("rejects invalid credentials", function()
      expect(false).to.be_falsy()
    end)
    
    -- Apply characteristic tag to individual test
    it("rate limits excessive attempts", function()
      firmo.tags("security", "rate-limit")
      expect(true).to.be.truthy()
    end)
  end)
  
  describe("Profile Management", function()
    -- Apply different feature tag
    firmo.tags("profile")
    
    it("updates user information", function()
      expect(true).to.be.truthy()
    end)
    
    -- Tag slow tests
    it("uploads profile picture", function()
      firmo.tags("slow", "file-upload")
      expect(true).to.be.truthy()
    end)
  end)
end)
```

This creates a hierarchical tag structure:
- All tests have the "api" tag
- All tests under "User API" have both "api" and "user" tags
- Tests under "Authentication" have "api", "user", and "auth" tags
- The rate limiting test has "api", "user", "auth", "security", and "rate-limit" tags

## Pattern Filtering Examples

### Filtering by Test Name

```lua
-- pattern_filtering.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Data Validation", function()
  it("validates email addresses", function()
    expect("user@example.com").to.match("@")
  end)
  
  it("validates phone numbers", function()
    expect("123-456-7890").to.match("%d+%-%d+%-%d+")
  end)
  
  it("validates postal codes", function()
    expect("12345").to.match("^%d+$")
  end)
end)

describe("Data Transformation", function()
  it("converts strings to numbers", function()
    expect(tonumber("42")).to.equal(42)
  end)
  
  it("formats dates properly", function()
    expect(string.format("%02d/%02d/%04d", 1, 15, 2023)).to.equal("01/15/2023")
  end)
  
  it("normalizes text data", function()
    expect(string.lower(" TEXT "):match("^%s*(.-)%s*$")).to.equal("text")
  end)
end)
```

Running with pattern filters:
```bash
# Run tests containing "validate"
lua test.lua --filter validate pattern_filtering.lua

# Run tests containing "format"
lua test.lua --filter format pattern_filtering.lua

# Run tests containing "data" (matches describe blocks)
lua test.lua --filter data pattern_filtering.lua
```

### Complex Pattern Matching

```lua
-- complex_patterns.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("String Utils", function()
  describe("Case Conversion", function()
    it("converts to uppercase", function()
      expect(string.upper("hello")).to.equal("HELLO")
    end)
    
    it("converts to lowercase", function()
      expect(string.lower("HELLO")).to.equal("hello")
    end)
  end)
  
  describe("Trimming", function()
    it("trims leading whitespace", function()
      expect(string.match("  hello", "%S.*")).to.equal("hello")
    end)
    
    it("trims trailing whitespace", function()
      expect(string.match("hello  ", ".*%S")).to.equal("hello")
    end)
  end)
end)

describe("Number Utils", function()
  describe("Rounding", function()
    it("rounds to nearest integer", function()
      expect(math.floor(3.7 + 0.5)).to.equal(4)
    end)
    
    it("rounds to decimal places", function()
      local function round(num, decimals)
        local mult = 10^(decimals or 0)
        return math.floor(num * mult + 0.5) / mult
      end
      expect(round(3.14159, 2)).to.equal(3.14)
    end)
  end)
end)
```

Running with complex patterns:
```bash
# Run tests with "trim" in the name
lua test.lua --filter trim complex_patterns.lua

# Run tests in the "Rounding" section
lua test.lua --filter Rounding complex_patterns.lua

# Run all test names starting with "converts"
lua test.lua --filter "^converts" complex_patterns.lua
```

## Combining Tags and Patterns

### Using Both Filtering Mechanisms

```lua
-- combined_filters.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("User Module", function()
  -- Apply tags for the entire user module
  firmo.tags("unit", "user")
  
  it("validates username format", function()
    expect("valid_user123").to.match("^%w+$")
  end)
  
  it("validates email format", function()
    expect("user@example.com").to.match("@")
  end)
  
  describe("Password Management", function()
    -- Add security tag to password tests
    firmo.tags("security")
    
    it("validates password strength", function()
      local function is_strong(pass)
        return #pass >= 8 and 
               pass:match("%d") and
               pass:match("%u") and
               pass:match("%l")
      end
      
      expect(is_strong("Abcd1234")).to.be.truthy()
      expect(is_strong("weak")).to.be_falsy()
    end)
    
    it("handles password reset", function()
      firmo.tags("integration", "email")
      expect(true).to.be.truthy()
    end)
  end)
end)

describe("Post Module", function()
  -- Apply different module tag
  firmo.tags("unit", "post")
  
  it("validates post title", function()
    expect("Valid Title").to.match("^%u")
  end)
  
  it("validates post content", function()
    expect("Content with at least 10 chars").to.have_length.above(10)
  end)
  
  it("handles post formatting", function()
    firmo.tags("formatting")
    expect(true).to.be.truthy()
  end)
end)
```

Running with combined filters:
```bash
# Run security-related tests with "password" in the name
lua test.lua --tags security --filter password combined_filters.lua

# Run all validation tests in the user module
lua test.lua --tags user --filter validate combined_filters.lua

# Run all unit tests with "format" in the name
lua test.lua --tags unit --filter format combined_filters.lua
```

## Practical Use Cases

### Running Fast Tests During Development

```lua
-- development_workflow.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Core Functionality", function()
  -- Fast unit tests for rapid development feedback
  firmo.tags("unit", "fast")
  
  it("calculates totals correctly", function()
    expect(1 + 2 + 3).to.equal(6)
  end)
  
  it("formats data properly", function()
    expect(string.format("%.2f", 10.1234)).to.equal("10.12")
  end)
  
  -- Integration tests that take longer
  describe("Database Operations", function()
    firmo.tags("integration", "db", "slow")
    
    it("inserts records correctly", function()
      -- This would be a slow database test
      expect(true).to.be.truthy()
    end)
    
    it("retrieves filtered results", function()
      -- This would be another slow database test
      expect(true).to.be.truthy()
    end)
  end)
  
  -- Back to fast unit tests
  firmo.tags("unit", "fast")
  it("validates input constraints", function()
    expect(function() assert(#"short" > 10) end).to.fail()
  end)
end)
```

During development:
```bash
# Run only fast tests for quick feedback
lua test.lua --tags fast development_workflow.lua
```

Before committing:
```bash
# Run all tests to verify everything works
lua test.lua development_workflow.lua
```

### Feature-Specific Testing

```lua
-- feature_testing.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- User authentication feature
describe("User Authentication", function()
  firmo.tags("auth", "unit")
  
  it("validates login credentials", function()
    expect(true).to.be.truthy()
  end)
  
  it("handles invalid passwords", function()
    expect(false).to.be_falsy()
  end)
  
  it("implements login rate limiting", function()
    firmo.tags("security")
    expect(true).to.be.truthy()
  end)
end)

-- User profile feature
describe("User Profile", function()
  firmo.tags("profile", "unit")
  
  it("displays user information", function()
    expect(true).to.be.truthy()
  end)
  
  it("allows editing profile data", function()
    expect(true).to.be.truthy()
  end)
  
  it("stores profile changes", function()
    firmo.tags("integration", "db")
    expect(true).to.be.truthy()
  end)
end)

-- Search feature
describe("Search Functionality", function()
  firmo.tags("search", "unit")
  
  it("returns matching results", function()
    expect(true).to.be.truthy()
  end)
  
  it("handles empty search queries", function()
    expect(true).to.be.truthy()
  end)
  
  it("paginates large result sets", function()
    firmo.tags("integration")
    expect(true).to.be.truthy()
  end)
  
  it("indexes content for fast searching", function()
    firmo.tags("performance", "slow")
    expect(true).to.be.truthy()
  end)
end)
```

When working on a specific feature:
```bash
# Work on authentication feature
lua test.lua --tags auth feature_testing.lua

# Focus on search feature
lua test.lua --tags search feature_testing.lua 
```

### CI Pipeline Organization

```lua
-- ci_test_suite.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Apply tags based on test type
local function setup_test_suite()
  -- Get test type from environment or default to all
  local test_type = os.getenv("TEST_TYPE") or "all"
  
  if test_type == "unit" then
    firmo.only_tags("unit")
  elseif test_type == "integration" then
    firmo.only_tags("integration")
  elseif test_type == "performance" then
    firmo.only_tags("performance")
  end
  
  -- Skip slow tests in quick mode
  if os.getenv("QUICK_MODE") == "1" then
    firmo.exclude_tags("slow")
  end
  
  -- Load all test files
  require("tests/module1_test")
  require("tests/module2_test")
  require("tests/module3_test")
end

-- Execute the test suite
setup_test_suite()
```

In CI configuration:
```yaml
# .github/workflows/test.yml
jobs:
  unit-tests:
    runs-on: ubuntu-latest
    env:
      TEST_TYPE: unit
    steps:
      - run: lua test.lua ci_test_suite.lua
      
  integration-tests:
    runs-on: ubuntu-latest
    env:
      TEST_TYPE: integration
    steps:
      - run: lua test.lua ci_test_suite.lua
      
  performance-tests:
    runs-on: ubuntu-latest
    env:
      TEST_TYPE: performance
    steps:
      - run: lua test.lua ci_test_suite.lua
```

## Advanced Examples

### Custom Tag Combinations

```lua
-- tag_combinations.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Function to determine if we should run tests based on env vars
local function should_run(tags)
  local run_type = os.getenv("RUN_TYPE") or "all"
  
  if run_type == "all" then
    return true
  elseif run_type == "quick" then
    -- Run unit tests that aren't slow
    return tags.unit and not tags.slow
  elseif run_type == "pre-commit" then
    -- Run all tests except slow ones
    return not tags.slow
  elseif run_type == "nightly" then
    -- Run all tests including slow ones
    return true
  elseif run_type == "security" then
    -- Run only security-related tests
    return tags.security
  end
  
  return false
end

describe("File System", function()
  -- Basic tag for all tests in this group
  local tags = {unit = true}
  
  it("reads file contents", function()
    if should_run(tags) then
      expect(true).to.be.truthy()
    end
  end)
  
  it("writes to files", function()
    -- Add slow tag for this test
    local test_tags = {unit = true, slow = true}
    if should_run(test_tags) then
      expect(true).to.be.truthy()
    end
  end)
  
  it("validates file permissions", function()
    -- Add security tag for this test
    local test_tags = {unit = true, security = true}
    if should_run(test_tags) then
      expect(true).to.be.truthy()
    end
  end)
end)
```

### Dynamic Tag Application

```lua
-- dynamic_tags.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Apply tags based on feature list
local features = {
  auth = true,
  profile = true,
  payment = os.getenv("INCLUDE_PAYMENT") == "1"
}

-- Tests for authentication
if features.auth then
  describe("Authentication", function()
    firmo.tags("auth", "unit")
    
    it("validates login credentials", function()
      expect(true).to.be.truthy()
    end)
  end)
end

-- Tests for user profile
if features.profile then
  describe("User Profile", function()
    firmo.tags("profile", "unit")
    
    it("displays user information", function()
      expect(true).to.be.truthy()
    end)
  end)
end

-- Tests for payment processing
if features.payment then
  describe("Payment Processing", function()
    firmo.tags("payment", "integration")
    
    it("processes credit card payments", function()
      expect(true).to.be.truthy()
    end)
  end)
end
```

## Conclusion

These examples demonstrate the flexibility and power of Firmo's test filtering system. By effectively using tags and pattern filters, you can create a testing workflow that adapts to different development scenarios, CI pipelines, and feature areas.

Key practices to remember:
1. Use consistent tag naming across your test suite
2. Apply tags at the appropriate level in your test hierarchy
3. Combine tags and pattern filters for precise test selection
4. Create standard tag sets for different testing scenarios
5. Consider environment-specific test filtering for CI/CD pipelines
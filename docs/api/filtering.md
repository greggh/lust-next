# Test Filtering API
This document describes the test filtering and tagging capabilities provided by Lust-Next.

## Overview
Lust-Next provides a powerful system for filtering tests based on tags and name patterns. This allows you to run specific subsets of tests, which is particularly useful for:

- Running only unit tests or only integration tests
- Running tests for a specific feature
- Running only tests that match a particular pattern
- Excluding tests that might be slow or dependent on external resources

## Tagging Functions

### lust.tags(...)
Adds tags to a test or describe block. Tags are inherited by nested tests.
**Parameters:**

- `...` (strings): One or more tags to apply
**Returns:**

- The lust object (for chaining)
**Example:**

```lua
describe("Database operations", function()
  lust.tags("db", "integration")
  it("connects to the database", function()
    -- This test has the "db" and "integration" tags
  end)
  describe("Queries", function()
    it("executes a SELECT query", function()
      -- This test also has the "db" and "integration" tags
    end)
    lust.tags("slow")
    it("performs a complex join", function()
      -- This test has "db", "integration", and "slow" tags
    end)
  end)
end)

```text

### lust.only_tags(...)
Filters tests to only run those with the specified tags.
**Parameters:**

- `...` (strings): One or more tags to filter by
**Returns:**

- The lust object (for chaining)
**Example:**

```lua
-- Only run tests tagged with "unit"
lust.only_tags("unit")
-- Only run tests tagged with both "fast" and "critical"
lust.only_tags("fast", "critical")

```text

### lust.filter(pattern)
Filters tests to only run those with names matching the specified pattern.
**Parameters:**

- `pattern` (string): A Lua pattern to match against test names
**Returns:**

- The lust object (for chaining)
**Example:**

```lua
-- Only run tests with "validation" in their name
lust.filter("validation")
-- Only run tests that match a specific pattern
lust.filter("^user%s+%w+$")

```text

### lust.reset_filters()
Clears all active filters.
**Returns:**

- The lust object (for chaining)
**Example:**

```lua
-- Apply a filter
lust.only_tags("unit")
-- Run some tests...
-- Clear the filter
lust.reset_filters()

```text

## Filtering from the Command Line
Lust-Next supports filtering tests from the command line when running tests directly.

### --tags Option
The `--tags` option allows you to specify tags to filter by, separated by commas.
**Example:**

```bash

# Run only tests tagged with "unit"
lua lust-next.lua --tags unit

# Run tests tagged with either "fast" or "critical"
lua lust-next.lua --tags fast,critical

```text

### --filter Option
The `--filter` option allows you to specify a pattern to match against test names.
**Example:**

```bash

# Run only tests with "validation" in their name
lua lust-next.lua --filter validation

```text

### Combining Filters
You can combine tag and pattern filters to further narrow the tests that run.
**Example:**

```bash

# Run only "unit" tests with "validation" in their name
lua lust-next.lua --tags unit --filter validation

```text

## Examples

### Basic Tag Filtering

```lua
-- Define tests with tags
describe("User module", function()
  lust.tags("unit")
  it("validates username", function()
    -- Test code here
  end)
  it("validates email", function()
    -- Test code here
  end)
  lust.tags("integration", "slow")
  it("stores user in database", function()
    -- Test code here
  end)
end)
-- Run only unit tests
lust.only_tags("unit")
lust.run_discovered("./tests")

```text

### Pattern Filtering

```lua
describe("String utilities", function()
  it("trims whitespace", function()
    -- Test code here
  end)
  it("formats currency", function()
    -- Test code here
  end)
end)
-- Run only tests related to formatting
lust.filter("format")
lust.run_discovered("./tests")

```text

### Programmatic Control

```lua
-- Test suite setup
local function run_tests(options)
  -- Reset any previous filters
  lust.reset_filters()
  -- Apply tags filter if specified
  if options.tags then
    lust.only_tags(unpack(options.tags))
  end
  -- Apply name filter if specified
  if options.pattern then
    lust.filter(options.pattern)
  end
  -- Run the tests
  return lust.run_discovered("./tests")
end
-- Examples of usage
run_tests({}) -- Run all tests
run_tests({tags = {"unit"}}) -- Run only unit tests
run_tests({pattern = "validation"}) -- Run only validation tests
run_tests({tags = {"unit"}, pattern = "validation"}) -- Run only unit validation tests

```text

### Using with CI Systems

```lua
-- ci_tests.lua
local lust = require("lust-next")
-- Based on environment variable, run different test subsets
local test_type = os.getenv("TEST_TYPE") or "all"
if test_type == "unit" then
  lust.only_tags("unit")
elseif test_type == "integration" then
  lust.only_tags("integration")
elseif test_type == "performance" then
  lust.only_tags("performance")
end
-- Run the filtered tests
local success = lust.run_discovered("./tests")
os.exit(success and 0 or 1)

```text

### Organizing Tests with Tags

```lua
-- user_test.lua
local lust = require("lust-next")
local describe, it = lust.describe, lust.it
describe("User module", function()
  -- Authentication tests
  describe("Authentication", function()
    lust.tags("auth", "unit")
    it("validates credentials", function()
      -- Test code
    end)
    it("hashes passwords", function()
      -- Test code
    end)
  end)
  -- Profile tests
  describe("Profile", function()
    lust.tags("profile", "unit")
    it("updates user info", function()
      -- Test code
    end)
    lust.tags("profile", "integration")
    it("saves profile to database", function()
      -- Test code
    end)
  end)
end)

```text

## Best Practices

1. **Use consistent tag naming**: Establish a convention for tag names (e.g., "unit", "integration", "slow") and use them consistently.
1. **Tag at the right level**: Apply tags to describe blocks when all contained tests share the same tags, and to individual tests for specific cases.
1. **Keep tags focused**: Use tags that have clear meaning and purpose, rather than overly specific or redundant tags.
1. **Document your tags**: Maintain a list of standard tags and their meanings for your project.
1. **Consider CI integration**: Set up your CI system to run different subsets of tests based on tags for faster feedback.
1. **Use pattern filtering sparingly**: Pattern filtering is powerful but can be less explicit than tag-based filtering.


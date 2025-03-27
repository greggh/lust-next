# Output Formatting Examples

This document provides practical examples of customizing test output and report formats in Firmo.

## Basic Output Formats

The examples below demonstrate the various output formats available through both command-line options and programmatic configuration.

### Standard Output Format

```lua
-- standard_output.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Configure standard output format
firmo.format({
  use_color = true,
  show_success_detail = true,
  compact = false
})

-- Sample test suite
describe("Calculator", function()
  it("adds two numbers", function()
    expect(2 + 2).to.equal(4)
  end)
  
  it("subtracts two numbers", function()
    expect(5 - 3).to.equal(2)
  end)
  
  it("divides numbers", function()
    expect(10 / 2).to.equal(5)
  end)
  
  it("fails on division by zero", function()
    expect(function() return 1/0 end).to.fail()
  end)
end)
```

When executed:
```
$ lua test.lua standard_output.lua

Calculator
  ✓ adds two numbers
  ✓ subtracts two numbers
  ✓ divides numbers
  ✓ fails on division by zero

Running 4 tests complete
✓ 4 passed, 0 failed
```

### Compact Output Format

```lua
-- compact_output.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Configure compact output format
firmo.format({
  compact = true,
  show_success_detail = false
})

-- Sample test suite
describe("Calculator", function()
  it("adds two numbers", function()
    expect(2 + 2).to.equal(4)
  end)
  
  it("subtracts two numbers", function()
    expect(5 - 3).to.equal(2)
  end)
  
  it("multiplies numbers", function()
    expect(3 * 4).to.equal(12)
  end)
  
  it("divides numbers", function()
    expect(10 / 2).to.equal(5)
  end)
  
  it("fails with bad math", function()
    expect(2 + 2).to.equal(5) -- This will fail
  end)
end)
```

When executed:
```
$ lua test.lua compact_output.lua

Calculator
  ....✗

Running 5 tests complete
✓ 4 passed, 1 failed

FAIL Calculator fails with bad math
Expected: 5
Actual: 4
```

### Dot Output Format

```lua
-- dot_output.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Configure dot output format
firmo.format({
  dot_mode = true
})

-- Sample test suite with multiple describe blocks
describe("String Utils", function()
  it("concatenates strings", function()
    expect("hello" .. " world").to.equal("hello world")
  end)
  
  it("converts to uppercase", function()
    expect(string.upper("hello")).to.equal("HELLO")
  end)
end)

describe("Array Utils", function()
  it("inserts elements", function()
    local arr = {1, 2, 3}
    table.insert(arr, 4)
    expect(arr[4]).to.equal(4)
  end)
  
  it("sorts elements", function()
    local arr = {3, 1, 2}
    table.sort(arr)
    expect(arr[1]).to.equal(1)
  end)
end)

describe("Math Utils", function()
  it("rounds numbers", function()
    expect(math.floor(1.8)).to.equal(1)
  end)
  
  it("fails with incorrect calculation", function()
    expect(1 + 1).to.equal(3) -- This will fail
  end)
end)
```

When executed:
```
$ lua test.lua dot_output.lua

.....✗

Running 6 tests complete
✓ 5 passed, 1 failed

FAIL Math Utils fails with incorrect calculation
Expected: 3
Actual: 2
```

### Summary Only Format

```lua
-- summary_output.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Configure summary only output
firmo.format({
  summary_only = true
})

-- Sample test suite
describe("Calculator", function()
  it("adds two numbers", function()
    expect(2 + 2).to.equal(4)
  end)
  
  it("subtracts two numbers", function()
    expect(5 - 3).to.equal(2)
  end)
end)

describe("String Utils", function()
  it("concatenates strings", function()
    expect("hello" .. " world").to.equal("hello world")
  end)
end)
```

When executed:
```
$ lua test.lua summary_output.lua

Running 3 tests complete
✓ 3 passed, 0 failed
```

## Error Reporting Examples

### Basic Error Display

```lua
-- error_output.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Configure error output without stack traces
firmo.format({
  use_color = true,
  show_trace = false
})

-- Sample test with errors
describe("Error Examples", function()
  it("expects equality", function()
    expect(1 + 1).to.equal(3) -- Will fail
  end)
  
  it("expects type matching", function()
    expect(123).to.be.a("string") -- Will fail
  end)
  
  it("succeeds correctly", function()
    expect(true).to.be.truthy()
  end)
end)
```

When executed:
```
$ lua test.lua error_output.lua

Error Examples
  ✗ expects equality
    Expected: 3
    Actual: 2
  ✗ expects type matching
    Expected type: string
    Actual type: number
    Value: 123
  ✓ succeeds correctly

Running 3 tests complete
✓ 1 passed, 2 failed
```

### Stack Trace Display

```lua
-- stack_trace_output.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Configure with stack traces
firmo.format({
  use_color = true,
  show_trace = true
})

-- Helper function that will fail
local function divide(a, b)
  if b == 0 then
    error("Cannot divide by zero")
  end
  return a / b
end

-- Sample test with error
describe("Division", function()
  it("divides two numbers", function()
    expect(divide(10, 2)).to.equal(5)
  end)
  
  it("fails when dividing by zero", function()
    expect(divide(10, 0)).to.equal("This won't execute")
  end)
end)
```

When executed:
```
$ lua test.lua stack_trace_output.lua

Division
  ✓ divides two numbers
  ✗ fails when dividing by zero
    Error: Cannot divide by zero
    stack traceback:
      stack_trace_output.lua:14: in function 'divide'
      stack_trace_output.lua:25: in function <stack_trace_output.lua:24>
      [C]: in function 'xpcall'
      ...

Running 2 tests complete
✓ 1 passed, 1 failed
```

## Customizing Appearance

### Color and Indentation

```lua
-- appearance_customization.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Configure appearance
firmo.format({
  use_color = true,        -- Use colored output
  indent_char = '  ',      -- Use spaces for indentation
  indent_size = 2          -- Two spaces per level
})

-- Sample nested test structure
describe("Outer Group", function()
  it("has a top-level test", function()
    expect(true).to.be.truthy()
  end)
  
  describe("Inner Group Level 1", function()
    it("has a nested test", function()
      expect(1 + 1).to.equal(2)
    end)
    
    describe("Inner Group Level 2", function()
      it("has a deeply nested test", function()
        expect("test").to.be.a("string")
      end)
    end)
  end)
end)
```

When executed with custom indentation:
```
$ lua test.lua appearance_customization.lua

Outer Group
  ✓ has a top-level test
  Inner Group Level 1
    ✓ has a nested test
    Inner Group Level 2
      ✓ has a deeply nested test

Running 3 tests complete
✓ 3 passed, 0 failed
```

### No Color Output

```lua
-- no_color_output.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Disable colored output
firmo.nocolor() -- Shorthand for firmo.format({ use_color = false })

-- Sample test suite
describe("Plain Text Output", function()
  it("passes a test", function()
    expect(true).to.be.truthy()
  end)
  
  it("fails a test", function()
    expect(1 + 1).to.equal(3) -- Will fail
  end)
end)
```

The output will appear without ANSI color codes, suitable for terminals that don't support them.

## Environment-Based Configuration

### CI-Friendly Configuration

```lua
-- ci_output.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Check if running in CI environment
local in_ci = os.getenv("CI") == "true"

-- Configure based on environment
if in_ci then
  -- CI environment config - plain text, summary output
  firmo.format({
    use_color = false,      -- No colors for CI logs
    summary_only = false,   -- Show details for CI logs
    show_trace = true,      -- Include stack traces for debugging
    compact = false         -- Not compact for readability in logs
  })
else
  -- Local development config
  firmo.format({
    use_color = true,       -- Use colors locally
    show_trace = false,     -- No stack traces for cleaner output
    compact = true          -- Compact for faster feedback
  })
end

-- Sample tests
describe("Feature Tests", function()
  it("passes test one", function()
    expect(true).to.be.truthy()
  end)
  
  it("passes test two", function()
    expect(1 + 1).to.equal(2)
  end)
  
  it("fails test three", function()
    expect(false).to.be.truthy() -- Will fail
  end)
end)
```

To simulate CI environment:
```
$ CI=true lua test.lua ci_output.lua
```

## Working with Report Formats

### HTML Report Generation

```lua
-- html_report_example.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local central_config = require("lib.core.central_config")
local reporting = require("lib.reporting")

-- Configure HTML formatter
reporting.configure_formatter("html", {
  theme = "dark",               -- Use dark theme
  show_line_numbers = true,     -- Show line numbers in source
  collapsible_sections = true,  -- Make sections collapsible
  highlight_syntax = true,      -- Use syntax highlighting
  include_legend = true         -- Show coverage legend
})

-- Sample test suite
describe("HTML Report Demo", function()
  it("demonstrates successful tests", function()
    expect(true).to.be.truthy()
    expect(1 + 1).to.equal(2)
    expect("test").to.be.a("string")
  end)
  
  it("demonstrates table comparison", function()
    local expected = {name = "test", value = 123}
    local actual = {name = "test", value = 123}
    expect(actual).to.equal(expected)
  end)
  
  it("demonstrates failure", function()
    expect(1 + 1).to.equal(3) -- Will fail
  end)
end)
```

To generate an HTML report:
```
$ lua test.lua --format html --output-file report.html html_report_example.lua
```

### JSON Report Generation

```lua
-- json_report_example.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local reporting = require("lib.reporting")

-- Configure JSON formatter
reporting.configure_formatter("json", {
  pretty = true,              -- Pretty-print JSON
  include_source = true,      -- Include source code
  include_stack_traces = true -- Include stack traces for failures
})

-- Sample test suite
describe("JSON Report Demo", function()
  it("passes test one", function()
    expect(true).to.be.truthy()
  end)
  
  it("passes test two", function()
    expect({1, 2, 3}).to.contain(2)
  end)
  
  it("fails test three", function()
    expect(5).to.be.a("string") -- Will fail
  end)
end)
```

To generate a JSON report:
```
$ lua test.lua --format json --output-file results.json json_report_example.lua
```

### Multiple Report Formats

```lua
-- multiple_reports.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local reporting = require("lib.reporting")

-- Configure multiple formatters
reporting.configure_formatters({
  html = {
    theme = "light",
    show_line_numbers = true
  },
  json = {
    pretty = true
  },
  junit = {
    include_stack_traces = true
  }
})

-- Sample test suite
describe("Multiple Reports Demo", function()
  it("successfully tests a feature", function()
    expect(true).to.be.truthy()
  end)
  
  it("fails a test case", function()
    expect(false).to.be.truthy() -- Will fail
  end)
end)
```

To generate multiple reports:
```
$ lua test.lua --format html,json,junit multiple_reports.lua
```

## Custom Formatter Example

```lua
-- custom_formatter.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local reporting = require("lib.reporting")

-- Define a custom markdown formatter
local function markdown_formatter(results_data)
  local markdown = "# Test Results\n\n"
  
  -- Add summary
  markdown = markdown .. "## Summary\n\n"
  markdown = markdown .. "- **Total Tests**: " .. results_data.tests .. "\n"
  markdown = markdown .. "- **Passed**: " .. (results_data.tests - results_data.failures) .. "\n"
  markdown = markdown .. "- **Failed**: " .. results_data.failures .. "\n\n"
  
  -- Add test case details
  markdown = markdown .. "## Test Cases\n\n"
  for _, test_case in ipairs(results_data.test_cases or {}) do
    local status = test_case.status == "pass" and "✅" or "❌"
    markdown = markdown .. "### " .. status .. " " .. test_case.name .. "\n\n"
    
    if test_case.status == "fail" and test_case.failure then
      markdown = markdown .. "**Error:** " .. test_case.failure.message .. "\n\n"
      if test_case.failure.details then
        markdown = markdown .. "```\n" .. test_case.failure.details .. "\n```\n\n"
      end
    end
  end
  
  -- Add timestamp
  markdown = markdown .. "Generated on " .. os.date() .. "\n"
  
  return markdown
end

-- Register the custom formatter
reporting.register_results_formatter("markdown", markdown_formatter)

-- Sample test suite
describe("Custom Formatter Demo", function()
  it("passes a test", function()
    expect(1 + 1).to.equal(2)
  end)
  
  it("fails a test", function()
    expect("hello").to.equal("world") -- Will fail
  end)
end)
```

To use the custom formatter:
```
$ lua test.lua --format markdown --output-file results.md custom_formatter.lua
```

## Conclusion

These examples demonstrate the flexibility of Firmo's output and formatting system. By choosing the right output format for each context, you can optimize your testing workflow for different scenarios, from rapid development to continuous integration and reporting.

Key points to remember:
1. Use standard or detailed output when developing and debugging
2. Use compact or dot mode for quick feedback with large test suites
3. Configure CI-specific output for readable logs
4. Generate HTML or other formatted reports for sharing and analysis
5. Create custom formatters for specialized output needs
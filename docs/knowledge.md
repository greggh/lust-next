# Docs Knowledge

## Purpose
Documentation and guides for the Firmo testing framework.

## Minimal Test Example
```lua
local firmo = require('firmo')
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe('Calculator', function()
  it('adds numbers correctly', function()
    expect(2 + 2).to.equal(4)
  end)

  it('handles errors properly', { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return divide(1, 0)
    end)()
    expect(err).to.exist()
    expect(err.message).to.match("divide by zero")
  end)
end)
```

## Critical Rules
- NEVER add special case code
- ALWAYS use central_config
- NEVER create custom configs
- NEVER hardcode paths
- ALWAYS handle errors properly

## Error Handling Pattern
```lua
-- Standard error handling
local success, result, err = error_handler.try(function()
  return risky_operation()
end)

if not success then
  logger.error("Operation failed", {
    error = err,
    category = err.category
  })
  return nil, err
end

-- Error testing pattern
it("handles errors", { expect_error = true }, function()
  local result, err = test_helper.with_error_capture(function()
    return function_that_throws()
  end)()
  expect(err).to.exist()
  expect(err.category).to.equal("VALIDATION")
end)
```

## Logging System
```lua
-- Get module logger
local logger = logging.get_logger("module_name")

-- Structured logging
logger.info("Operation completed", {
  duration = time_taken,
  items_processed = count
})

-- Error logging
logger.error("Operation failed", {
  error = err,
  category = err.category,
  context = operation_context
})
```

## Documentation Links
- Tasks: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/tasks/firmo-tasks.md`
- Architecture: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/plans/firmo-architecture.md`
- Project Status: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/project-status.md`

## JSDoc Annotations
```lua
---@class Calculator
---@field add fun(a: number, b: number): number Adds two numbers
---@field subtract fun(a: number, b: number): number Subtracts b from a
local Calculator = {}

--- Adds two numbers together
---@param a number First number
---@param b number Second number
---@return number sum The sum of a and b
function Calculator.add(a, b)
  return a + b
end
```

## Testing Guidelines
- Use expect-style assertions
- Clean up test resources
- Avoid external dependencies
- Use mocks/stubs to isolate
- Document complex logic
- Handle all error cases
- Update JSDoc annotations
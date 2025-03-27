# Documentation Knowledge

## Purpose
Documentation and guides for the Firmo testing framework.

## Core Modules
```lua
-- Test Structure
describe("Group", function()
  it("test case", function()
    expect(value).to.exist()
  end)
end)

-- Async Testing
it.async("async test", function(done)
  async_operation(function(result)
    expect(result).to.exist()
    done()
  end)
end)

-- Coverage Tracking
firmo.coverage_options.enabled = true
firmo.coverage_options.include = {"src/*.lua"}
firmo.coverage_options.exclude = {"tests/*.lua"}

-- Quality Validation
firmo.quality_options.enabled = true
firmo.quality_options.level = 3

-- Module Reset
local fresh_module = firmo.reset_module("app.module")
```

## Running Tests
```bash
# Run all tests
lua test.lua tests/

# Run with coverage
lua test.lua --coverage tests/

# Run with tags
lua test.lua --tags unit,fast tests/

# Run with pattern
lua test.lua --filter validation tests/

# Run with watching
lua test.lua --watch tests/
```

## Architectural Principles
1. **Centralized Configuration**
   - All settings through central_config
   - No direct configuration
   - Use .firmo-config.lua

2. **No Special Cases**
   - Solutions must be general
   - No file-specific handling
   - Avoid workarounds

3. **Error Handling**
   - Use structured errors
   - Include context
   - Follow patterns

4. **Modularity**
   - Clear boundaries
   - Defined responsibilities
   - Clean interfaces

5. **Documentation**
   - API references
   - Practical guides
   - Real examples

## Latest Features
- Enhanced Modular Reporting
  - Multiple formats
  - Fallback mechanisms
  - Error handling
  - Improved operations

- Module Reset Utilities
  - reset_module()
  - with_fresh_module()
  - Clean test state

- Enhanced Async Testing
  - parallel_async()
  - Improved wait_until()
  - Better performance

## Critical Rules
- Use central_config
- No special cases
- Handle errors properly
- Document changes
- Test thoroughly
- Follow patterns
- Clean up state
- Monitor performance

## Best Practices
- Write clear tests
- Handle errors
- Clean up resources
- Document behavior
- Use helpers
- Follow patterns
- Monitor performance
- Test edge cases

## Version Info
- Current: 0.7.4
- Status: Alpha
- Not for production
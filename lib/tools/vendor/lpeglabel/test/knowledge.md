# LPegLabel Test Knowledge

## Purpose
Test suite for LPegLabel parsing library integration.

## Test Categories
```lua
-- Basic pattern tests
local function test_basic_patterns()
  local p = lpeg.P("abc")
  assert(p:match("abc") == 4)
  assert(p:match("abx") == nil)
end

-- Label tests
local function test_labels()
  local p = lpeg.T(ErrLabel) + lpeg.P("a")
  assert(p:match("b") == nil)
  assert(p.labels[1] == ErrLabel)
end

-- Grammar tests
local function test_grammars()
  local g = lpeg.P{
    "S";
    S = lpeg.V"A" * lpeg.V"B",
    A = lpeg.P"a"^1,
    B = lpeg.P"b"^1
  }
  assert(g:match("aaabbb") == 7)
end
```

## Critical Rules
- Test all label types
- Verify error messages
- Check recovery
- Test large inputs
- Validate patterns

## Test Categories
- Basic patterns
- Labels and errors
- Complex grammars
- Recovery scenarios
- Performance cases
- Memory usage
- Error handling
- Large inputs

## Best Practices
- Test edge cases
- Verify labels
- Check memory
- Document patterns
- Clean up resources
- Test thoroughly
- Handle errors
- Validate results
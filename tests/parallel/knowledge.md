# Parallel Testing Knowledge

## Test Setup
```lua
describe("Parallel Tests", function()
  before(function()
    -- Setup runs before each test
  end)
  
  after(function()
    -- Cleanup runs after each test
  end)
end)
```
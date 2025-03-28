-- firmo v3 coverage instrumentation tests
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local instrumentation = require("lib.coverage.v3.instrumentation")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Coverage v3 Instrumentation", function()
  -- Helper to normalize whitespace for comparison
  local function normalize_whitespace(str)
    return str:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  end

  -- Helper to count occurrences of a pattern
  local function count_pattern(str, pattern)
    local count = 0
    for _ in str:gmatch(pattern) do
      count = count + 1
    end
    return count
  end

  it("should instrument code with tracking calls while preserving behavior", function()
    local source = [=[
      local function add(a, b)
        return a + b
      end

      local function multiply(a, b)
        local result = 0
        for i = 1, b do
          result = add(result, a)
        end
        return result
      end

      return multiply(3, 4)
    ]=]

    -- Instrument the code
    local instrumented, sourcemap = instrumentation.instrument(source)
    expect(instrumented).to.exist()
    expect(sourcemap).to.exist()

    -- Verify sourcemap tracks original lines
    expect(sourcemap.get_original_line(1)).to.equal(1)  -- function declaration
    expect(sourcemap.get_original_line(2)).to.equal(2)  -- return statement
    expect(sourcemap.get_original_line(5)).to.equal(5)  -- second function
    
    -- Verify tracking calls were added
    expect(count_pattern(instrumented, "track_line")).to.be.greater_than(0)
    expect(count_pattern(instrumented, "track_function_entry")).to.be.greater_than(0)
    expect(count_pattern(instrumented, "track_function_exit")).to.be.greater_than(0)
    expect(count_pattern(instrumented, "track_branch")).to.be.greater_than(0)
    
    -- Load and run both versions to verify behavior preserved
    local original_chunk = load(source)
    local instrumented_chunk = load(instrumented)
    
    expect(original_chunk).to.exist()
    expect(instrumented_chunk).to.exist()
    
    local original_result = original_chunk()
    local instrumented_result = instrumented_chunk()
    
    expect(instrumented_result).to.equal(original_result)
    expect(instrumented_result).to.equal(12) -- 3 * 4 = 12
  end)

  it("should handle syntax errors gracefully", { expect_error = true }, function()
    local source = [=[
      local x = -- incomplete
      return x
    ]=]

    local result, err = test_helper.with_error_capture(function()
      return instrumentation.instrument(source)
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("syntax error")
  end)

  it("should preserve comments and whitespace", function()
    local source = [=[
      -- Header comment
      local x = 1 -- Line comment
      
      --[[ Block
          comment ]]
      local y = 2
      
      return x + y -- Result
    ]=]

    local instrumented = instrumentation.instrument(source)
    expect(instrumented).to.exist()

    -- Comments should still be present
    expect(instrumented).to.match("%-%-[^\n]*Header comment")
    expect(instrumented).to.match("%-%-[^\n]*Line comment")
    expect(instrumented).to.match("-%-%[%[.-comment.-]]")
    expect(instrumented).to.match("%-%-[^\n]*Result")

    -- Whitespace/newlines preserved (except indentation which may change)
    local original_lines = select(2, source:gsub("\n", "\n"))
    local instrumented_lines = select(2, instrumented:gsub("\n", "\n"))
    expect(instrumented_lines).to.be.at_least(original_lines)
  end)

  it("should add tracking calls at key points", function()
    local source = [=[
      local function test(x)
        if x > 0 then
          return "positive"
        else
          return "negative"
        end
      end
    ]=]

    local instrumented = instrumentation.instrument(source)
    expect(instrumented).to.exist()

    -- Should have tracking calls for:
    -- 1. Function entry
    expect(count_pattern(instrumented, "track_function_entry")).to.be.greater_than(0)
    -- 2. Conditional branches
    expect(count_pattern(instrumented, "track_branch")).to.be.greater_than(0)
    -- 3. Return statements
    expect(count_pattern(instrumented, "track_line")).to.be.greater_than(0)
  end)

  it("should handle all Lua syntax correctly", { expect_error = true }, function()
    local source = [=[
      -- Variables and values
      local a, b = 1, "string"
      local t = {1, 2, 3, key = "value"}
      
      -- Control structures
      while a < 10 do
        a = a + 1
      end
      
      for i = 1, 10 do
        b = b .. i
      end
      
      for k, v in pairs(t) do
        print(k, v)
      end
      
      if a > b then
        return a
      elseif a < b then
        return b
      else
        return a + b
      end
      
      -- Functions
      local function f1() end
      local f2 = function() end
      function t.method() end
      
      -- OOP style
      local obj = setmetatable({}, {
        __index = function(t, k)
          return k .. " not found"
        end
      })
      
      -- Varargs
      local function vararg(...)
        local args = {...}
        return #args
      end
      
      -- Error handling
      local ok, err = pcall(function()
        error("test error")
      end)
      
      -- Coroutines
      local co = coroutine.create(function()
        coroutine.yield("yielded")
      end)
      
      -- String manipulation
      local s = "test"
      s = s:upper():lower():gsub("t", "T")
    ]=]

    local instrumented, sourcemap = instrumentation.instrument(source)
    expect(instrumented).to.exist()
    expect(sourcemap).to.exist()

    -- Should be able to load and run the instrumented code
    local chunk = load(instrumented)
    expect(chunk).to.exist()

    -- Execute the code with error capture since we expect it to fail
    local result, err = test_helper.with_error_capture(function()
      return chunk()
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("attempt to compare string with number")

    -- Should have appropriate tracking calls
    expect(count_pattern(instrumented, "track_line")).to.be.greater_than(0)
    expect(count_pattern(instrumented, "track_function_entry")).to.be.greater_than(0)
    expect(count_pattern(instrumented, "track_function_exit")).to.be.greater_than(0)
    expect(count_pattern(instrumented, "track_branch")).to.be.greater_than(0)
  end)
end)
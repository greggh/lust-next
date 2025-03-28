-- firmo v3 coverage loader tests
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local hook = require("lib.coverage.v3.loader.hook")
local cache = require("lib.coverage.v3.loader.cache")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("Coverage v3 Module Loading", function()
  -- Create test directory and files
  local test_dir

  before(function()
    -- Create test directory with sample modules
    test_dir = test_helper.create_temp_test_directory()

    -- Create a simple module
    test_dir.create_file("simple.lua", [[
      local function add(a, b)
        return a + b
      end
      return { add = add }
    ]])

    -- Create a module with conditional logic
    test_dir.create_file("complex.lua", [[
      local M = {}
      function M.calculate(a, b, operation)
        if operation == "add" then
          return a + b
        elseif operation == "subtract" then
          return a - b
        else
          return a * b
        end
      end
      return M
    ]])

    -- Add test directory to package path
    package.path = test_dir.path .. "/?.lua;" .. package.path
  end)

  after(function()
    -- Remove test directory from package path
    package.path = package.path:gsub(test_dir.path .. "/?.lua;", "")

    -- Uninstall loader hook if installed
    hook.uninstall()

    -- Clear cache
    cache.clear()
  end)

  it("should install and uninstall loader hook", function()
    -- Install hook
    local installed = hook.install()
    expect(installed).to.be_truthy()

    -- Try to install again (should fail)
    local second_install = hook.install()
    expect(second_install).to.be_falsy()

    -- Uninstall hook
    local uninstalled = hook.uninstall()
    expect(uninstalled).to.be_truthy()

    -- Try to uninstall again (should fail)
    local second_uninstall = hook.uninstall()
    expect(second_uninstall).to.be_falsy()
  end)

  it("should load and instrument modules", function()
    -- Install hook
    hook.install()

    -- Load simple module
    local simple = require("simple")
    expect(simple).to.exist()
    expect(simple.add).to.exist()
    expect(simple.add(2, 3)).to.equal(5)

    -- Load complex module
    local complex = require("complex")
    expect(complex).to.exist()
    expect(complex.calculate).to.exist()
    expect(complex.calculate(10, 5, "add")).to.equal(15)
    expect(complex.calculate(10, 5, "subtract")).to.equal(5)
    expect(complex.calculate(10, 5, "multiply")).to.equal(50)
  end)

  it("should cache instrumented modules", function()
    -- Install hook
    hook.install()

    -- Load module first time
    local first = require("simple")
    expect(first).to.exist()

    -- Clear memory cache but keep file cache
    memory_cache = {}

    -- Load module second time (should use file cache)
    local second = require("simple")
    expect(second).to.exist()
    expect(second.add(2, 3)).to.equal(5)

    -- Clear all cache
    cache.clear()

    -- Load module third time (should re-instrument)
    local third = require("simple")
    expect(third).to.exist()
    expect(third.add(2, 3)).to.equal(5)
  end)

  it("should handle syntax errors gracefully", { expect_error = true }, function()
    -- Create module with syntax error
    test_dir.create_file("invalid.lua", [[
      local function broken(
        return 42
      end
    ]])

    -- Install hook
    hook.install()

    -- Try to load invalid module
    local result, err = test_helper.with_error_capture(function()
      return require("invalid")
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("syntax error")
  end)

  it("should handle runtime errors in modules", { expect_error = true }, function()
    -- Create module with runtime error
    test_dir.create_file("runtime_error.lua", [[
      error("Something went wrong!")
      return {}
    ]])

    -- Install hook
    hook.install()

    -- Try to load module with runtime error
    local result, err = test_helper.with_error_capture(function()
      return require("runtime_error")
    end)()

    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Something went wrong!")
  end)
end)
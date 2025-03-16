-- Basic test for firmo
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
---@diagnostic disable-next-line: unused-local
local before, after = firmo.before, firmo.after

-- Try to load the logging module
local logging, logger
local function try_load_logger()
  if not logger then
    local ok, log_module = pcall(require, "lib.tools.logging")
    if ok and log_module then
      logging = log_module
      logger = logging.get_logger("test.firmo")

      if logger and logger.debug then
        logger.debug("Firmo core test initialized", {
          module = "test.firmo",
          test_type = "unit",
          test_focus = "core API",
        })
      end
    end
  end
  return logger
end

-- Initialize logger
local log = try_load_logger()

describe("firmo", function()
  if log then
    log.info("Beginning firmo core tests", {
      test_group = "firmo_core",
      test_focus = "API functions",
    })
  end

  it("has required functions", function()
    expect(firmo.describe).to.be.a("function")
    expect(firmo.it).to.be.a("function")
    expect(firmo.expect).to.be.a("function")
    expect(firmo.spy).to.exist()
  end)

  it("passes simple tests", function()
    if log then
      log.debug("Testing basic assertions")
    end
    expect(1).to.equal(1)
    expect("hello").to.equal("hello")
    expect({ 1, 2 }).to.equal({ 1, 2 })
  end)

  it("has spy functionality", function()
    if log then
      log.debug("Testing spy functionality")
    end
    -- Test the spy functionality which is now implemented
    expect(firmo.spy).to.exist()
    -- The spy is a module with new and on functions
    expect(firmo.spy.new).to.be.a("function")
    expect(firmo.spy.on).to.be.a("function")

    -- Test basic spy functionality
    local test_fn = function(a, b)
      return a + b
    end
    local spied = firmo.spy.new(test_fn)

    -- Spy should work like the original function
    ---@diagnostic disable-next-line: need-check-nil
    expect(spied(2, 3)).to.equal(5)

    -- Spy should track calls
    ---@diagnostic disable-next-line: need-check-nil
    expect(spied.calls).to.be.a("table")
    ---@diagnostic disable-next-line: need-check-nil
    ---@diagnostic disable-next-line: need-check-nil
    expect(#spied.calls).to.equal(1)
    ---@diagnostic disable-next-line: need-check-nil
    expect(spied.calls[1][1]).to.equal(2)
    ---@diagnostic disable-next-line: need-check-nil
    expect(spied.calls[1][2]).to.equal(3)
    ---@diagnostic disable-next-line: need-check-nil
    expect(spied.call_count).to.equal(1)
  end)

  if log then
    log.info("Firmo core tests completed", {
      status = "success",
      test_group = "firmo_core",
    })
  end
end)

-- Tests are run by run_all_tests.lua or scripts/runner.lua
-- No need to call firmo() explicitly here

-- Basic test for lust-next
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect
local before, after = lust.before, lust.after

-- Try to load the logging module
local logging, logger
local function try_load_logger()
  if not logger then
    local ok, log_module = pcall(require, "lib.tools.logging")
    if ok and log_module then
      logging = log_module
      logger = logging.get_logger("test.lust")
      
      if logger and logger.debug then
        logger.debug("Lust core test initialized", {
          module = "test.lust",
          test_type = "unit",
          test_focus = "core API"
        })
      end
    end
  end
  return logger
end

-- Initialize logger
local log = try_load_logger()

describe("lust-next", function()
  if log then
    log.info("Beginning lust core tests", {
      test_group = "lust_core",
      test_focus = "API functions"
    })
  end

  it("has required functions", function()
    expect(lust.describe).to.be.a("function")
    expect(lust.it).to.be.a("function")
    expect(lust.expect).to.be.a("function")
    expect(lust.spy).to.exist()
  end)
  
  it("passes simple tests", function()
    if log then log.debug("Testing basic assertions") end
    expect(1).to.equal(1)
    expect("hello").to.equal("hello")
    expect({1, 2}).to.equal({1, 2})
  end)
  
  it("has spy functionality", function()
    if log then log.debug("Testing spy functionality") end
    -- Test the spy functionality which is now implemented
    expect(lust.spy).to.exist()
    -- The spy is a module with new and on functions
    expect(lust.spy.new).to.be.a("function")
    expect(lust.spy.on).to.be.a("function")
    
    -- Test basic spy functionality
    local test_fn = function(a, b) return a + b end
    local spied = lust.spy.new(test_fn)
    
    -- Spy should work like the original function
    expect(spied(2, 3)).to.equal(5)
    
    -- Spy should track calls
    expect(spied.calls).to.be.a("table")
    expect(#spied.calls).to.equal(1)
    expect(spied.calls[1][1]).to.equal(2)
    expect(spied.calls[1][2]).to.equal(3)
    expect(spied.call_count).to.equal(1)
  end)

  if log then
    log.info("Lust core tests completed", {
      status = "success",
      test_group = "lust_core"
    })
  end
end)

-- Tests are run by run_all_tests.lua or scripts/runner.lua
-- No need to call lust() explicitly here
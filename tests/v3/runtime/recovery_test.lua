-- Recovery module tests
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local recovery = require("lib.coverage.v3.runtime.recovery")
local fs = require("lib.tools.filesystem")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Coverage v3 Runtime Recovery", function()
  describe("Data Validation", function()
    it("should validate valid coverage data", function()
      local data = {
        data = {
          [1] = 1,  -- Line 1 executed
          [2] = 3   -- Line 2 executed and covered
        },
        counts = {
          [1] = 1,  -- Line 1 executed once
          [2] = 2   -- Line 2 executed twice
        }
      }
      
      local valid, errors = recovery.validate_data(data)
      expect(valid).to.be_truthy()
      expect(errors).to_not.exist()
    end)

    it("should detect invalid data structure", function()
      local data = "not a table"
      local valid, errors = recovery.validate_data(data)
      expect(valid).to_not.be_truthy()
      expect(errors[1]).to.match("must be a table")
    end)

    it("should detect invalid line numbers", function()
      local data = {
        data = {
          ["invalid"] = 1
        },
        counts = {
          [1] = 1
        }
      }
      
      local valid, errors = recovery.validate_data(data)
      expect(valid).to_not.be_truthy()
      expect(errors[1]).to.match("Invalid line number")
    end)

    it("should detect invalid flags", function()
      local data = {
        data = {
          [1] = "invalid"
        },
        counts = {
          [1] = 1
        }
      }
      
      local valid, errors = recovery.validate_data(data)
      expect(valid).to_not.be_truthy()
      expect(errors[1]).to.match("Invalid flags")
    end)
  end)

  describe("Data Repair", function()
    it("should repair inconsistent data", function()
      local data = {
        data = {
          [1] = 1,
          ["invalid"] = "bad",
          [2] = 3
        },
        counts = {
          [1] = 1,
          ["invalid"] = -1,
          [3] = "bad"
        }
      }
      
      local repaired, repairs = recovery.repair_data(data)
      expect(repaired.data[1]).to.equal(1)
      expect(repaired.data[2]).to.equal(3)
      expect(repaired.data["invalid"]).to_not.exist()
      expect(repaired.counts[1]).to.equal(1)
      expect(repaired.counts["invalid"]).to_not.exist()
      expect(repaired.counts[3]).to_not.exist()
      expect(#repairs).to.be.greater_than(0)
    end)

    it("should initialize missing data", function()
      local data = {}
      local repaired, repairs = recovery.repair_data(data)
      expect(repaired.data).to.exist()
      expect(repaired.counts).to.exist()
      expect(#repairs).to.equal(2)  -- Initialized both data and counts
    end)

    it("should ensure consistency between data and counts", function()
      local data = {
        data = {
          [1] = 1,
          [2] = 3
        },
        counts = {
          [1] = 1
          -- Missing count for line 2
        }
      }
      
      local repaired, repairs = recovery.repair_data(data)
      expect(repaired.counts[2]).to.equal(0)  -- Initialized missing count
      expect(#repairs).to.equal(1)
    end)
  end)

  describe("Backup and Restore", function()
    it("should create and restore backups", function()
      -- Create test data
      local data = {
        data = {
          [1] = 1,
          [2] = 3
        },
        counts = {
          [1] = 1,
          [2] = 2
        }
      }
      
      -- Write test data to cache
      local cache_dir = "./.firmo-cache/v3/coverage"
      fs.create_directory(cache_dir)
      fs.write_file(cache_dir .. "/test_file.json", require("lib.tools.json").encode(data))
      
      -- Create backup
      local success = recovery.backup_data("test_file")
      expect(success).to.be_truthy()
      
      -- Modify cache data
      data.data[1] = 2  -- Change some data
      fs.write_file(cache_dir .. "/test_file.json", require("lib.tools.json").encode(data))
      
      -- Restore backup
      success = recovery.restore_backup("test_file")
      expect(success).to.be_truthy()
      
      -- Verify restored data
      local content = fs.read_file(cache_dir .. "/test_file.json")
      local restored = require("lib.tools.json").decode(content)
      expect(restored.data[1]).to.equal(1)  -- Original value restored
    end)

    it("should handle missing backups gracefully", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return recovery.restore_backup("nonexistent")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("not found")
    end)
  end)

  describe("Corruption Detection", function()
    it("should detect missing fields", function()
      local data = {
        data = {
          [1] = 1
        }
        -- Missing counts field
      }
      
      local corrupted, issues = recovery.detect_corruption(data)
      expect(corrupted).to.be_truthy()
      expect(#issues).to.equal(1)
      expect(issues[1].type).to.equal("missing_field")
    end)

    it("should detect inconsistencies", function()
      local data = {
        data = {
          [1] = 1,
          [2] = 3
        },
        counts = {
          [1] = 1,
          [3] = 1  -- Count without data
        }
      }
      
      local corrupted, issues = recovery.detect_corruption(data)
      expect(corrupted).to.be_truthy()
      expect(#issues).to.equal(2)  -- Missing count and orphaned count
    end)

    it("should detect invalid values", function()
      local data = {
        data = {
          [1] = "invalid",
          ["bad"] = 1
        },
        counts = {
          [1] = -1,
          ["bad"] = "invalid"
        }
      }
      
      local corrupted, issues = recovery.detect_corruption(data)
      expect(corrupted).to.be_truthy()
      expect(#issues).to.be.greater_than(0)
    end)

    it("should pass valid data", function()
      local data = {
        data = {
          [1] = 1,
          [2] = 3
        },
        counts = {
          [1] = 1,
          [2] = 2
        }
      }
      
      local corrupted, issues = recovery.detect_corruption(data)
      expect(corrupted).to_not.be_truthy()
      expect(#issues).to.equal(0)
    end)
  end)
end)
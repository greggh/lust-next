-- Optimized store tests
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local optimized_store = require("lib.coverage.v3.runtime.optimized_store")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before = firmo.before

describe("Coverage v3 Runtime Optimized Store", function()
  before(function()
    -- Reset store before each test
    optimized_store.reset()
  end)

  it("should track line execution with bit flags", function()
    -- Record some executions
    optimized_store.record_execution("file1", 1)
    optimized_store.record_execution("file1", 2)
    optimized_store.record_execution("file1", 1)  -- Line 1 executed twice

    -- Get file data
    local data = optimized_store.get_file_data("file1")
    expect(data).to.exist()
    expect(data.lines[1].execution_count).to.equal(2)  -- Line 1 executed twice
    expect(data.lines[2].execution_count).to.equal(1)  -- Line 2 executed once
  end)

  it("should track line coverage with bit flags", function()
    -- Record execution and coverage
    optimized_store.record_execution("file1", 1)
    optimized_store.record_execution("file1", 2)
    optimized_store.record_coverage("file1", 1)  -- Only line 1 is covered

    -- Check line states
    expect(optimized_store.get_line_state("file1", 1)).to.equal("covered")
    expect(optimized_store.get_line_state("file1", 2)).to.equal("executed")
    expect(optimized_store.get_line_state("file1", 3)).to.equal("not_covered")
  end)

  it("should handle multiple files", function()
    -- Record data for different files
    optimized_store.record_execution("file1", 1)
    optimized_store.record_coverage("file1", 1)
    optimized_store.record_execution("file2", 1)

    -- Check file data separation
    local data1 = optimized_store.get_file_data("file1")
    local data2 = optimized_store.get_file_data("file2")

    expect(data1.lines[1].covered).to.be_truthy()
    expect(data2.lines[1].covered).to_not.be_truthy()
  end)

  it("should calculate file summary", function()
    -- Record mixed coverage data
    optimized_store.record_execution("file1", 1)  -- Executed only
    optimized_store.record_execution("file1", 2)
    optimized_store.record_coverage("file1", 2)   -- Executed and covered
    -- Line 3 not executed or covered

    -- Get file summary
    local data = optimized_store.get_file_data("file1")
    expect(data.summary).to.exist()
    expect(data.summary.total_lines).to.equal(2)
    expect(data.summary.covered_lines).to.equal(1)
    expect(data.summary.executed_lines).to.equal(2)
    expect(data.summary.not_covered_lines).to.equal(0)
    expect(data.summary.coverage_percent).to.equal(50)
    expect(data.summary.execution_percent).to.equal(100)
  end)

  it("should calculate global summary", function()
    -- Record data across multiple files
    optimized_store.record_execution("file1", 1)
    optimized_store.record_coverage("file1", 1)
    optimized_store.record_execution("file2", 1)

    -- Get global summary
    local summary = optimized_store.get_summary()
    expect(summary.total_files).to.equal(2)
    expect(summary.total_lines).to.equal(2)
    expect(summary.covered_lines).to.equal(1)
    expect(summary.executed_lines).to.equal(2)
    expect(summary.coverage_percent).to.equal(50)
    expect(summary.execution_percent).to.equal(100)
  end)

  it("should handle missing data gracefully", function()
    -- Try to get data for non-existent file
    local data = optimized_store.get_file_data("nonexistent")
    expect(data).to_not.exist()

    -- Check line state for non-existent file/line
    expect(optimized_store.get_line_state("nonexistent", 1)).to.equal("not_covered")
  end)

  it("should reset data", function()
    -- Record some data
    optimized_store.record_execution("file1", 1)
    optimized_store.record_coverage("file1", 1)

    -- Reset all data
    optimized_store.reset()

    -- Verify everything is cleared
    expect(optimized_store.get_file_data("file1")).to_not.exist()
    expect(optimized_store.get_summary().total_files).to.equal(0)
  end)

  it("should flush and load data", function()
    -- Record some data
    optimized_store.record_execution("file1", 1)
    optimized_store.record_coverage("file1", 1)
    optimized_store.record_execution("file2", 1)

    -- Flush data to disk
    optimized_store.flush()

    -- Reset in-memory data
    optimized_store.reset()
    expect(optimized_store.get_file_data("file1")).to_not.exist()

    -- Load data back
    optimized_store.load()

    -- Verify data was restored
    local data1 = optimized_store.get_file_data("file1")
    local data2 = optimized_store.get_file_data("file2")
    expect(data1).to.exist()
    expect(data2).to.exist()
    expect(data1.lines[1].covered).to.be_truthy()
    expect(data2.lines[1].covered).to_not.be_truthy()
  end)
end)
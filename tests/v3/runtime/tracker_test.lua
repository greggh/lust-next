-- Runtime tracker tests
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local tracker = require("lib.coverage.v3.runtime.tracker")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before = firmo.before

describe("Coverage v3 Runtime Tracker", function()
  before(function()
    -- Reset tracker before each test
    tracker.reset()
  end)

  it("should track line execution", function()
    -- Track some lines
    tracker.track_line("file1", 1)
    tracker.track_line("file1", 2)
    tracker.track_line("file1", 1)  -- Line 1 executed twice

    -- Get execution data
    local data = tracker.get_execution_data("file1")
    expect(data).to.exist()
    expect(data[1]).to.equal(2)  -- Line 1 executed twice
    expect(data[2]).to.equal(1)  -- Line 2 executed once
  end)

  it("should track function entry and exit", function()
    -- Track function calls
    tracker.track_function_entry("file1", "func1")
    tracker.track_function_exit("file1", "func1")
    tracker.track_function_entry("file1", "func1")  -- Called twice

    -- Get function data
    local data = tracker.get_function_data("file1")
    expect(data).to.exist()
    expect(data["func1"]).to.exist()
    expect(data["func1"].entries).to.equal(2)
    expect(data["func1"].exits).to.equal(1)
  end)

  it("should track branch execution", function()
    -- Track branch decisions
    tracker.track_branch("file1", "branch1", true)   -- Taken
    tracker.track_branch("file1", "branch1", false)  -- Not taken
    tracker.track_branch("file1", "branch1", true)   -- Taken again

    -- Get branch data
    local data = tracker.get_branch_data("file1")
    expect(data).to.exist()
    expect(data["branch1"]).to.exist()
    expect(data["branch1"].taken).to.equal(2)
    expect(data["branch1"].not_taken).to.equal(1)
  end)

  it("should handle multiple files", function()
    -- Track lines in different files
    tracker.track_line("file1", 1)
    tracker.track_line("file2", 1)

    -- Track functions in different files
    tracker.track_function_entry("file1", "func1")
    tracker.track_function_entry("file2", "func1")

    -- Track branches in different files
    tracker.track_branch("file1", "branch1", true)
    tracker.track_branch("file2", "branch1", true)

    -- Verify data separation
    local exec1 = tracker.get_execution_data("file1")
    local exec2 = tracker.get_execution_data("file2")
    expect(exec1[1]).to.equal(1)  -- Each file's line 1 executed once
    expect(exec2[1]).to.equal(1)
    expect(exec1).to_not.be(exec2)  -- Different table instances

    local func1 = tracker.get_function_data("file1")
    local func2 = tracker.get_function_data("file2")
    expect(func1["func1"].entries).to.equal(1)  -- Each file's func1 entered once
    expect(func2["func1"].entries).to.equal(1)
    expect(func1).to_not.be(func2)  -- Different table instances

    local branch1 = tracker.get_branch_data("file1")
    local branch2 = tracker.get_branch_data("file2")
    expect(branch1["branch1"].taken).to.equal(1)  -- Each file's branch1 taken once
    expect(branch2["branch1"].taken).to.equal(1)
    expect(branch1).to_not.be(branch2)  -- Different table instances
  end)

  it("should reset tracking data", function()
    -- Track some data
    tracker.track_line("file1", 1)
    tracker.track_function_entry("file1", "func1")
    tracker.track_branch("file1", "branch1", true)

    -- Reset all data
    tracker.reset()

    -- Verify everything is cleared
    expect(tracker.get_execution_data("file1")).to_not.exist()
    expect(tracker.get_function_data("file1")).to_not.exist()
    expect(tracker.get_branch_data("file1")).to_not.exist()
  end)

  it("should handle missing data gracefully", function()
    -- Try to get data for non-existent file
    expect(tracker.get_execution_data("nonexistent")).to_not.exist()
    expect(tracker.get_function_data("nonexistent")).to_not.exist()
    expect(tracker.get_branch_data("nonexistent")).to_not.exist()
  end)

  it("should handle high execution counts", function()
    -- Track a line many times
    for i = 1, 1000 do
      tracker.track_line("file1", 1)
    end

    -- Verify count
    local data = tracker.get_execution_data("file1")
    expect(data).to.exist()
    expect(data[1]).to.equal(1000)
  end)
end)
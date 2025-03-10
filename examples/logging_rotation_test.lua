-- Test case for the log rotation system
local lust = require("lust-next")
local logging = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")

local describe, it, expect = lust.describe, lust.it, lust.expect

describe("Log Rotation System", function()
  -- Clean up any existing test logs before we start
  local test_log_dir = "logs"
  local test_log_file = "rotation_test.log"
  local full_log_path = test_log_dir .. "/" .. test_log_file
  
  -- Create logs directory if it doesn't exist
  fs.ensure_directory_exists(test_log_dir)
  
  -- Remove existing logs if they exist
  if fs.file_exists(full_log_path) then
    fs.remove_file(full_log_path)
  end
  
  -- Remove any rotated logs
  for i = 1, 5 do
    local rotated_log = full_log_path .. "." .. i
    if fs.file_exists(rotated_log) then
      fs.remove_file(rotated_log)
    end
  end
  
  -- Configure logging with very small file size
  logging.configure({
    level = logging.LEVELS.DEBUG,
    timestamps = true,
    use_colors = true,
    output_file = test_log_file,
    log_dir = test_log_dir,
    max_file_size = 100, -- Very small size (100 bytes) to trigger rotation quickly
    max_log_files = 3    -- Keep 3 rotated log files
  })
  
  -- Get a test logger
  local logger = logging.get_logger("RotationTest")
  
  it("creates log directory if it doesn't exist", function()
    -- The directory should exist after our setup and the logging initialization
    expect(fs.directory_exists(test_log_dir)).to.be_truthy()
  end)
  
  it("creates log file on first write", function()
    -- Write first log
    logger.info("First log message")
    
    -- Check if log file exists
    expect(fs.file_exists(full_log_path)).to.be_truthy()
  end)
  
  it("rotates log file when it reaches max_file_size", function()
    -- Write enough logs to trigger rotation
    for i = 1, 20 do
      logger.info("Log message " .. i .. " to trigger rotation: " .. string.rep("x", 20))
    end
    
    -- At this point, the original log should have been rotated to .1
    expect(fs.file_exists(full_log_path .. ".1")).to.be_truthy()
    
    -- The main log file should still exist (new one created after rotation)
    expect(fs.file_exists(full_log_path)).to.be_truthy()
  end)
  
  it("handles multiple rotations correctly", function()
    -- Write enough logs to trigger another rotation
    for i = 1, 20 do
      logger.info("Second batch log message " .. i .. ": " .. string.rep("y", 20))
    end
    
    -- Now we should have logs .1 and .2
    expect(fs.file_exists(full_log_path .. ".1")).to.be_truthy()
    expect(fs.file_exists(full_log_path .. ".2")).to.be_truthy()
    
    -- Write even more logs to trigger a third rotation
    for i = 1, 20 do
      logger.info("Third batch log message " .. i .. ": " .. string.rep("z", 20))
    end
    
    -- Now we should have logs .1, .2, and .3
    expect(fs.file_exists(full_log_path .. ".1")).to.be_truthy()
    expect(fs.file_exists(full_log_path .. ".2")).to.be_truthy()
    expect(fs.file_exists(full_log_path .. ".3")).to.be_truthy()
  end)
  
  it("respects max_log_files setting", function()
    -- Write more logs to trigger another rotation beyond max_log_files
    for i = 1, 20 do
      logger.info("Fourth batch log message " .. i .. ": " .. string.rep("w", 20))
    end
    
    -- We should still have only 3 rotated logs (.1, .2, .3) 
    -- since max_log_files = 3, and file .4 should not exist
    expect(fs.file_exists(full_log_path .. ".1")).to.be_truthy()
    expect(fs.file_exists(full_log_path .. ".2")).to.be_truthy()
    expect(fs.file_exists(full_log_path .. ".3")).to.be_truthy()
    expect(fs.file_exists(full_log_path .. ".4")).to.be_falsey()
  end)
  
  it("handles log content correctly after rotation", function()
    -- Write a distinctive message
    logger.info("FINAL TEST MESSAGE")
    
    -- This message should be in the current log file
    local log_content = fs.read_file(full_log_path)
    expect(log_content).to.contain("FINAL TEST MESSAGE")
  end)
end)

print("Log rotation tests completed. Check the logs directory for test log files.")
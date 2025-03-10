-- Example demonstrating the enhanced logging system with log rotation
local lust = require("lust-next")
local logging = require("lib.tools.logging")

-- Create a sample config file with logging settings
print("Creating a sample configuration with logging settings")

-- Configure the logging system directly (without config file)
logging.configure({
  level = logging.LEVELS.DEBUG,
  timestamps = true,
  use_colors = true,
  output_file = "debug_rotation.log",
  log_dir = "logs",
  max_file_size = 512, -- Very small size for demo purposes - 512 bytes
  max_log_files = 3  -- Keep 3 rotated log files
})

-- Create module loggers
local mod1_logger = logging.get_logger("module1")
local mod2_logger = logging.get_logger("module2")

-- Set module-specific log levels
logging.set_module_level("module1", logging.LEVELS.DEBUG)
logging.set_module_level("module2", logging.LEVELS.INFO)

print("Writing log messages to demonstrate log rotation...")

-- Generate enough log entries to trigger rotation
for i = 1, 50 do
  mod1_logger.debug("This is debug message " .. i .. " from module1")
  mod1_logger.info("This is info message " .. i .. " from module1")
  
  mod2_logger.info("This is info message " .. i .. " from module2")
  
  -- Add some errors and warnings
  if i % 10 == 0 then
    mod1_logger.error("Error occurred at iteration " .. i)
    mod2_logger.warn("Warning at iteration " .. i)
  end
end

print("Done! Check the logs directory for generated log files.")
print("You should see: logs/debug_rotation.log and rotated files like logs/debug_rotation.log.1")

-- Show how to use the logging with global config
print("\nExample of using logging configured via global config:")
print("Add the following to your .lust-next-config.lua file:")
print([[
  logging = {
    level = 3, -- INFO level
    modules = {
      module1 = 4, -- DEBUG level for module1
      module2 = 2  -- WARN level for module2
    },
    timestamps = true,
    use_colors = true,
    output_file = "lust-next.log",
    log_dir = "logs",
    max_file_size = 10 * 1024 * 1024, -- 10MB
    max_log_files = 5
  }
]])

-- To test the configuration-based approach, you would normally:
-- 1. Create .lust-next-config.lua with the settings above
-- 2. In your modules, get the logger and configure from config:
-- 
-- local logging = require("lib.tools.logging")
-- local logger = logging.get_logger("my_module")
-- logging.configure_from_config("my_module")
-- 
-- 3. Then use the logger as normal:
-- logger.info("This is an info message")
-- logger.debug("This is a debug message")
-- logger.error("This is an error message")
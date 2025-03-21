-- Cleanup script for test files in the scripts directory
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")
local logger = logging.get_logger("cleanup_script_tests")

logger.info("Starting cleanup of test files in scripts directory")

-- Files to delete (no longer needed or already have proper tests)
local files_to_delete = {
  "./scripts/test_static_analyzer.lua",
  "./scripts/test_coverage_static_analysis.lua",
  "./scripts/run_tests.lua",
  "./scripts/test_summary_check.lua",
}

-- Files that have been converted to proper tests
local files_converted = {
  {
    source = "./scripts/test_parser.lua",
    destination = "./tests/tools/parser_test.lua",
    status = "Converted to proper test"
  },
  {
    source = "./scripts/test_lpeglabel.lua",
    destination = "./tests/tools/vendor/lpeglabel_test.lua",
    status = "Converted to proper test"
  },
}

-- Execute deletion of files
logger.info("Deleting obsolete test files:")
for _, file in ipairs(files_to_delete) do
  if fs.file_exists(file) then
    logger.info("  - Deleting: " .. file)
    local success, err = fs.delete_file(file)
    if not success then
      logger.error("Failed to delete file: " .. file, { error = tostring(err) })
    end
  else
    logger.warn("File not found: " .. file)
  end
end

-- Report on converted files
logger.info("Files converted to proper tests:")
for _, file in ipairs(files_converted) do
  logger.info("  - " .. file.source .. " -> " .. file.destination .. " (" .. file.status .. ")")
end

logger.info("Cleanup complete")
logger.info("Summary:")
logger.info("  - Files deleted: " .. #files_to_delete)
logger.info("  - Files converted: " .. #files_converted)
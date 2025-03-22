--[[
    coverage_filesystem_integration.lua - Example showing coverage module using filesystem module
    
    This example demonstrates the integration between the coverage module and
    the filesystem module for file discovery and reporting.
    
    Run this example with:
    lua examples/coverage_filesystem_integration.lua
]]

local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")

print("Coverage Module with Filesystem Integration")
print("-------------------------------------------\n")

-- Set up coverage configuration
coverage.config.enabled = true
coverage.config.debug = true
coverage.config.source_dirs = {"lib"}
coverage.config.discover_uncovered = true

-- Initialize coverage
coverage.init()

print("\nInitializing coverage and discovering files...")
-- Discover source files
local files = coverage.discover_source_files()

-- Show discovered files
print("\nDiscovered files:")
local count = 0
for file_path in pairs(files) do
    count = count + 1
    if count <= 5 then
        print("  " .. file_path)
    end
end

if count > 5 then
    print("  ... and " .. (count - 5) .. " more files")
end

-- Generate a coverage report
print("\nGenerating coverage report...")
local report_path = "/tmp/coverage-report.html"
local report_data = coverage.get_report_data()
local reporting = require("lib.reporting")
local success, err = reporting.save_coverage_report(report_path, report_data, "html")

if success then
    print("Coverage report saved to: " .. report_path)
else
    print("Error saving report: " .. (err or "unknown error"))
end

print("\nReport content stats:")
local report_content = fs.read_file(report_path)
if report_content then
    print("  Report size: " .. #report_content .. " bytes")
    print("  Report lines: " .. select(2, report_content:gsub("\n", "\n")))
else
    print("  Unable to read report")
end

print("\nDone!")
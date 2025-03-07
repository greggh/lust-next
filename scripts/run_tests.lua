#!/usr/bin/env lua
-- Main test runner script for lust-next

-- Get the root directory
local lust_dir = arg[0]:match("(.-)[^/\\]+$") or "./"
if lust_dir == "" then lust_dir = "./" end
lust_dir = lust_dir .. "../"

-- Add scripts directory to package path
package.path = lust_dir .. "?.lua;" .. lust_dir .. "scripts/?.lua;" .. package.path

-- Load lust-next and utility modules
local lust_next = require("lust-next")
local discover = require("discover")
local runner = require("runner")

-- Parse command line arguments
local dir = "./tests"
local pattern = "*_test.lua"
local run_single_file = nil
local codefix_enabled = false
local codefix_command = nil
local codefix_target = nil

local i = 1
while i <= #arg do
  if arg[i] == "--dir" and arg[i+1] then
    dir = arg[i+1]
    i = i + 2
  elseif arg[i] == "--pattern" and arg[i+1] then
    pattern = arg[i+1]
    i = i + 2
  elseif arg[i] == "--fix" then
    codefix_enabled = true
    codefix_command = "fix"
    
    if arg[i+1] and not arg[i+1]:match("^%-%-") then
      codefix_target = arg[i+1]
      i = i + 2
    else
      codefix_target = "."
      i = i + 1
    end
  elseif arg[i] == "--check" and arg[i+1] then
    codefix_enabled = true
    codefix_command = "check"
    codefix_target = arg[i+1]
    i = i + 2
  elseif arg[i]:match("%.lua$") then
    run_single_file = arg[i]
    i = i + 1
  else
    i = i + 1
  end
end

-- Check if codefix is requested
if codefix_enabled then
  -- Try to load codefix module
  local codefix, err
  local ok, loaded = pcall(function() codefix = require("src.codefix") end)
  
  if not ok or not codefix then
    print("Error: Codefix module not found: " .. (err or "unknown error"))
    os.exit(1)
  end
  
  -- Initialize codefix module
  codefix.init({
    enabled = true,
    verbose = true
  })
  
  -- Run the requested command
  print("\n" .. string.rep("-", 60))
  print("RUNNING CODEFIX: " .. codefix_command .. " " .. (codefix_target or ""))
  print(string.rep("-", 60))
  
  local codefix_args = {codefix_command, codefix_target}
  success = codefix.run_cli(codefix_args)
  
  -- Exit with appropriate status
  os.exit(success and 0 or 1)
end

-- Run tests
local success = false

if run_single_file then
  -- Run a single test file
  local results = runner.run_file(run_single_file, lust_next)
  success = results.success and results.errors == 0
else
  -- Find and run all tests
  local files = discover.find_tests(dir)
  success = runner.run_all(files, lust_next)
end

-- Exit with appropriate status
os.exit(success and 0 or 1)
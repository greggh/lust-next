-- JSON formatter for reports
local M = {}

-- Load the JSON module if available
local json_module
local ok, mod = pcall(require, "lib.reporting.json")
if ok then
  json_module = mod
else
  -- Simple fallback JSON encoder if module isn't available
  json_module = {
    encode = function(t)
      if type(t) ~= "table" then return tostring(t) end
      local s = "{"
      local first = true
      for k, v in pairs(t) do
        if not first then s = s .. "," else first = false end
        if type(k) == "string" then
          s = s .. '"' .. k .. '":'
        else
          s = s .. "[" .. tostring(k) .. "]:"
        end
        if type(v) == "table" then
          s = s .. json_module.encode(v)
        elseif type(v) == "string" then
          s = s .. '"' .. v .. '"'
        elseif type(v) == "number" or type(v) == "boolean" then
          s = s .. tostring(v)
        else
          s = s .. '"' .. tostring(v) .. '"'
        end
      end
      return s .. "}"
    end
  }
end

-- Generate a JSON coverage report
function M.format_coverage(coverage_data)
  -- Get summary report first
  local summary_fn = require("lib.reporting.formatters.summary").format_coverage
  local report = summary_fn(coverage_data)
  return json_module.encode(report)
end

-- Generate a JSON quality report
function M.format_quality(quality_data)
  -- Get summary report first
  local summary_fn = require("lib.reporting.formatters.summary").format_quality
  local report = summary_fn(quality_data)
  return json_module.encode(report)
end

-- Register formatters
return function(formatters)
  formatters.coverage.json = M.format_coverage
  formatters.quality.json = M.format_quality
end
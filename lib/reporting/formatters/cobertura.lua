-- Cobertura XML formatter for coverage reports
local M = {}

-- Helper function to escape XML special characters
local function escape_xml(str)
  if type(str) ~= "string" then
    return tostring(str or "")
  end
  
  return str:gsub("&", "&amp;")
            :gsub("<", "&lt;")
            :gsub(">", "&gt;")
            :gsub("\"", "&quot;")
            :gsub("'", "&apos;")
end

-- Get current timestamp in ISO format
local function get_timestamp()
  local current_time = os.time()
  return os.date("%Y-%m-%dT%H:%M:%S", current_time)
end

-- Helper function to calculate line rate
local function calculate_line_rate(covered, total)
  if total == 0 then return 1.0 end
  return covered / total
end

-- Generate Cobertura XML coverage report
-- Format specification: https://github.com/cobertura/cobertura/wiki/XML-Format
function M.format_coverage(coverage_data)
  -- Validate input
  if not coverage_data or not coverage_data.summary then
    return [[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-04.dtd">
<coverage lines-valid="0" lines-covered="0" line-rate="0" branches-valid="0" branches-covered="0" branch-rate="0" timestamp="]] .. os.time() .. [[" complexity="0" version="0.1">
  <sources><source>.</source></sources>
  <packages></packages>
</coverage>]]
  end
  
  -- Get summary data
  local summary = coverage_data.summary
  local total_lines = summary.total_lines or 0
  local covered_lines = summary.covered_lines or 0
  local line_rate = calculate_line_rate(covered_lines, total_lines)
  
  -- Start building XML
  local output = {
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-04.dtd">',
    '<coverage lines-valid="' .. total_lines .. '" lines-covered="' .. covered_lines .. 
    '" line-rate="' .. string.format("%.4f", line_rate) .. 
    '" branches-valid="0" branches-covered="0" branch-rate="0" timestamp="' .. 
    os.time() .. '" complexity="0" version="0.1">',
    '  <sources>',
    '    <source>.</source>',
    '  </sources>',
    '  <packages>'
  }
  
  -- Group files by "package" (directory)
  local packages = {}
  for filepath, file_data in pairs(coverage_data.files or {}) do
    -- Extract package (directory) from file path
    local package_path = "."
    if filepath:find("/") then
      package_path = filepath:match("^(.+)/[^/]+$") or "."
    end
    
    if not packages[package_path] then
      packages[package_path] = {
        files = {},
        total_lines = 0,
        covered_lines = 0
      }
    end
    
    -- Add file to package
    packages[package_path].files[filepath] = file_data
    packages[package_path].total_lines = packages[package_path].total_lines + (file_data.total_lines or 0)
    packages[package_path].covered_lines = packages[package_path].covered_lines + (file_data.covered_lines or 0)
  end
  
  -- Generate XML for each package
  for package_path, package_data in pairs(packages) do
    local package_line_rate = calculate_line_rate(package_data.covered_lines, package_data.total_lines)
    
    table.insert(output, '    <package name="' .. escape_xml(package_path) .. 
                        '" line-rate="' .. string.format("%.4f", package_line_rate) .. 
                        '" branch-rate="0" complexity="0">')
    table.insert(output, '      <classes>')
    
    -- Add class (file) information
    for filepath, file_data in pairs(package_data.files) do
      local filename = filepath:match("([^/]+)$") or filepath
      local file_line_rate = calculate_line_rate(file_data.covered_lines or 0, file_data.total_lines or 0)
      
      table.insert(output, '        <class name="' .. escape_xml(filename) .. 
                          '" filename="' .. escape_xml(filepath) .. 
                          '" line-rate="' .. string.format("%.4f", file_line_rate) .. 
                          '" branch-rate="0" complexity="0">')
      
      -- Add methods section (empty for now since we don't track method-level coverage)
      table.insert(output, '          <methods/>')
      
      -- Add lines section
      table.insert(output, '          <lines>')
      
      -- Add line hits
      local line_hits = {}
      for line_num, is_covered in pairs(file_data.lines or {}) do
        table.insert(line_hits, {
          line = line_num,
          hits = is_covered and 1 or 0
        })
      end
      
      -- Sort lines by number
      table.sort(line_hits, function(a, b) return a.line < b.line end)
      
      -- Add lines to XML
      for _, line_info in ipairs(line_hits) do
        table.insert(output, '            <line number="' .. line_info.line .. 
                            '" hits="' .. line_info.hits .. 
                            '" branch="false"/>')
      end
      
      table.insert(output, '          </lines>')
      table.insert(output, '        </class>')
    end
    
    table.insert(output, '      </classes>')
    table.insert(output, '    </package>')
  end
  
  -- Close XML
  table.insert(output, '  </packages>')
  table.insert(output, '</coverage>')
  
  return table.concat(output, '\n')
end

-- Register formatter
return function(formatters)
  formatters.coverage.cobertura = M.format_coverage
end
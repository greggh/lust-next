# HTML Formatter Enhancement Plan for Enhanced Line Classification

## Overview

This plan outlines the changes needed to enhance the HTML formatter to display the improved line classification information from the enhanced line classification system. The formatter should display rich tooltips and visual indicators to help users understand why specific lines are classified as executable or non-executable, making coverage reports more informative and easier to debug.

## Implementation Tasks

### 1. Update HTML Formatter Configuration

Add new configuration options to control the display of enhanced line classification information:

```lua
-- Add to the HTMLFormatterConfig class definition
---@field show_classification_details boolean Whether to show detailed classification information
---@field classification_tooltip_style string Style for classification tooltips ("hover", "click", or "both")
---@field highlight_multiline_constructs boolean Whether to highlight multiline constructs
---@field show_classification_reasons boolean Whether to show reasons for line classification

-- Update DEFAULT_CONFIG
local DEFAULT_CONFIG = {
  -- Existing options...
  show_classification_details = true,
  classification_tooltip_style = "hover",
  highlight_multiline_constructs = true,
  show_classification_reasons = true
}
```

### 2. Enhance the format_source_line Function

Update the format_source_line function to include enhanced classification information when available:

```lua
local function format_source_line(line_num, content, is_covered, is_executable, blocks, conditions, is_executed, execution_count, classification_data)
  -- Existing implementation...
  
  -- Add classification data to the tooltip if available
  if classification_data and config.show_classification_details then
    local classification_info = ""
    
    -- Add content type info
    if classification_data.content_type then
      classification_info = classification_info .. "Content type: " .. classification_data.content_type
    end
    
    -- Add classification reasons if available and enabled
    if classification_data.reasons and config.show_classification_reasons then
      classification_info = classification_info .. "; Reasons: " .. table.concat(classification_data.reasons, ", ")
    end
    
    -- Add classification data to tooltip
    if tooltip_data:match("title=") then
      -- Add to existing tooltip
      tooltip_data = tooltip_data:gsub('title="(.-)"', 'title="\\1 ' .. classification_info .. '"')
    else
      -- Create new tooltip
      tooltip_data = string.format(' title="%s"', classification_info)
    end
    
    -- Add CSS classes for content types
    if classification_data.content_type then
      local content_class = "content-" .. classification_data.content_type:gsub(" ", "-"):lower()
      class = class .. " " .. content_class
    end
    
    -- Add data attributes for script-based interactions
    if classification_data.content_type then
      block_info = block_info .. ' data-content-type="' .. classification_data.content_type .. '"'
    end
    if classification_data.reasons then
      block_info = block_info .. ' data-classification-reasons="' .. table.concat(classification_data.reasons, ";") .. '"'
    end
  end
  
  -- Rest of implementation...
}
```

### 3. Update the CSS Styles

Add new CSS styles for the enhanced line classification:

```css
/* Add to the CSS styles */
.content-code { }
.content-comment { background-color: rgba(200, 200, 200, 0.1); }
.content-multiline-comment { background-color: rgba(200, 200, 200, 0.2); }
.content-string { background-color: rgba(150, 200, 150, 0.1); }
.content-multiline-string { background-color: rgba(150, 200, 150, 0.2); }
.content-control-flow { font-weight: bold; }
.content-function-header { font-style: italic; }
```

### 4. Add JavaScript Functionality for Classification Details

Add JavaScript to handle displaying classification details:

```javascript
/* Add to the JavaScript section */
function showClassificationDetails(lineId) {
  const lineElement = document.getElementById(lineId);
  
  // Get data attributes
  const contentType = lineElement.getAttribute('data-content-type');
  const reasons = lineElement.getAttribute('data-classification-reasons');
  
  // Display in modal or popover
  const reasonsList = reasons ? reasons.split(';').map(r => `<li>${r}</li>`).join('') : '';
  
  const detailsHtml = `
    <div class="classification-details">
      <h4>Line Classification Details</h4>
      <p><strong>Content Type:</strong> ${contentType || 'Unknown'}</p>
      ${reasonsList ? `<p><strong>Classification Reasons:</strong></p><ul>${reasonsList}</ul>` : ''}
    </div>
  `;
  
  // Show details in modal or popover
  showDetailsModal(detailsHtml, lineElement);
}
```

### 5. Modify the format_coverage Function

Update the format_coverage function to pass classification data to the format_source_line function:

```lua
function M.format_coverage(coverage_data)
  -- Existing implementation...
  
  -- Inside the loop where files are processed
  for file_path, file_data in pairs(coverage_data.files) do
    -- Existing code...
    
    -- Process each line
    for line_num = 1, file_data.line_count or 0 do
      -- Get classification data if available
      local classification_data = file_data.line_classification and file_data.line_classification[line_num]
      
      -- Call format_source_line with classification data
      local line_html = format_source_line(
        line_num,
        file_data.source and file_data.source[line_num],
        file_data.lines and file_data.lines[line_num],
        file_data.executable_lines and file_data.executable_lines[line_num],
        blocks_for_line,
        conditions_for_line,
        file_data._executed_lines and file_data._executed_lines[line_num],
        file_data.execution_counts and file_data.execution_counts[line_num],
        classification_data -- Pass the classification data
      )
      
      -- Rest of implementation...
    end
  end
  
  -- Rest of implementation...
end
```

### 6. Add Interactive Classification Legend

Add a section to the coverage legend that explains line classification:

```lua
-- Add to the create_coverage_legend function
local function create_coverage_legend()
  local legend_html = [[
  <div class="coverage-legend">
    <!-- Existing legend content... -->
    
    <div class="legend-section">
      <h4>Line Classification</h4>
      <table class="legend-table">
        <tr>
          <td class="legend-item content-code"></td>
          <td>Code Line</td>
          <td>Executable code line</td>
        </tr>
        <tr>
          <td class="legend-item content-comment"></td>
          <td>Comment</td>
          <td>Single-line comment</td>
        </tr>
        <tr>
          <td class="legend-item content-multiline-comment"></td>
          <td>Multiline Comment</td>
          <td>Part of a multiline comment</td>
        </tr>
        <tr>
          <td class="legend-item content-string"></td>
          <td>String</td>
          <td>String literal</td>
        </tr>
        <tr>
          <td class="legend-item content-multiline-string"></td>
          <td>Multiline String</td>
          <td>Part of a multiline string</td>
        </tr>
        <tr>
          <td class="legend-item content-control-flow"></td>
          <td>Control Flow</td>
          <td>Control flow statement</td>
        </tr>
        <tr>
          <td class="legend-item content-function-header"></td>
          <td>Function Header</td>
          <td>Function declaration line</td>
        </tr>
      </table>
      <p class="legend-tip">Hover over a line to see detailed classification information</p>
    </div>
  </div>
  ]]
  
  return legend_html
end
```

## Testing Plan

1. Create test cases for different types of line classifications:
   - Regular executable code
   - Single-line comments
   - Multiline comments
   - String literals
   - Multiline strings
   - Function declarations
   - Control flow statements
   - Mixed lines (code with comments)

2. Test with different formatter configuration options:
   - With classification details enabled and disabled
   - With different tooltip styles
   - With multiline construct highlighting enabled and disabled

3. Verify that the tooltips work correctly and display the right information.

4. Check that the visual styles are applied correctly for different line types.

5. Ensure backward compatibility with existing code that doesn't use enhanced classification.

## Implementation Strategy

1. First, add the configuration options and update the formatting functions to handle classification data if available.
2. Then, enhance the CSS styles and JavaScript functionality.
3. Add the new legend section to explain the classification.
4. Create tests for the enhanced formatter.
5. Verify backward compatibility.

The implementation should be modular so that it works correctly whether enhanced classification data is available or not. This ensures that the formatter continues to work with older coverage data while providing enhanced information when available.
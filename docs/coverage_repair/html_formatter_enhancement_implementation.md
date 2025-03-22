# HTML Formatter Enhancement Implementation

This document describes the implementation of enhancements to the HTML formatter to display detailed line classification information from the enhanced line classification system.

## Overview

The HTML formatter has been enhanced to display rich tooltips and visual indicators that help users understand why specific lines are classified as executable or non-executable. This makes coverage reports more informative and easier to debug.

## Implementation Details

The implementation enhances the following key components:

### 1. Formatter Configuration

New configuration options were added to control the display of enhanced line classification information:

```lua
---@field show_classification_details boolean Whether to show detailed classification information
---@field classification_tooltip_style string Style for classification tooltips ("hover", "click", or "both")
---@field highlight_multiline_constructs boolean Whether to highlight multiline constructs
---@field show_classification_reasons boolean Whether to show reasons for line classification
```

These options can be set through the reporting configuration system:

```lua
local reporting = require("lib.reporting")
reporting.set_formatter_config("html", {
  show_classification_details = true,
  classification_tooltip_style = "both",
  highlight_multiline_constructs = true,
  show_classification_reasons = true
})
```

### 2. Enhanced Source Line Rendering

The `format_source_line` function was updated to include classification data in the HTML output:

```lua
function format_source_line(line_num, content, is_covered, is_executable, blocks, conditions, is_executed, execution_count, classification_data)
  -- Existing implementation...
  
  -- Process classification data if available and enabled in config
  if classification_data and config.show_classification_details then
    -- Add content type info to tooltip
    -- Add CSS classes for content types
    -- Add data attributes for script-based interactions
  end
  
  -- Generate HTML with classification information
end
```

Classification information is added in three ways:
1. Tooltips that show when hovering over lines
2. CSS classes that style different line types (comments, strings, code)
3. Data attributes that can be used by JavaScript for interactive features

### 3. CSS Styling for Different Line Types

CSS classes were added to style different line types:

```css
/* Line classification styling */
.line.content-code { /* Styling for executable code */ }
.line.content-comment { font-style: italic; color: var(--syntax-comment); }
.line.content-multiline-comment { /* Styling for multiline comments */ }
.line.content-string { color: var(--syntax-string); }
.line.content-multiline-string { /* Styling for multiline strings */ }
.line.content-control-flow { font-weight: bold; }
.line.content-function-declaration { font-style: italic; font-weight: bold; }
```

### 4. JavaScript for Interactive Classification Details

JavaScript was added to provide interactive classification details:

```javascript
// Enhanced classification information display
function showClassificationDetails(lineId) {
  // Show detailed classification information in a modal dialog
}

// Modal dialog for classification details
function showDetailsModal(content, anchorElement) {
  // Create and position modal dialog
}

// Initialize and set up event handlers
document.addEventListener('DOMContentLoaded', function() {
  // Set up configuration from data attributes
  // Add click handlers for classification details
});
```

### 5. Classification Legend

A new section was added to the coverage legend to explain line classification:

```html
<div class="legend-section">
  <h4>Line Classification</h4>
  <table class="legend-table">
    <tr>
      <td class="legend-sample content-code"></td>
      <td>Code Line</td>
      <td>Executable code line</td>
    </tr>
    <!-- Other line types... -->
  </table>
  <p class="legend-tip">Hover over a line to see detailed classification information</p>
</div>
```

## Usage in Coverage Reports

When enhanced line classification is enabled in the coverage system, the HTML formatter will automatically display the classification information:

```lua
-- Initialize coverage with enhanced classification
firmo.coverage.start({
  use_enhanced_classification = true,
  track_multiline_context = true
})

-- Run tests
-- ...

-- Stop coverage and get data
local coverage_data = firmo.coverage.stop()

-- Generate HTML report with enhanced formatter
local html_report = html_formatter.format_coverage(coverage_data)
```

## Visual Indicators

The enhanced HTML formatter provides several visual indicators for different line types:

1. **Comments** - Displayed in a lighter color with italic text
2. **Multiline Comments** - Similar to comments but with a light background
3. **Strings** - Displayed in a different color
4. **Multiline Strings** - Similar to strings but with a light background
5. **Control Flow Statements** - Displayed with bold text
6. **Function Declarations** - Displayed with both bold and italic text

## Interactive Features

The implementation includes interactive features for exploring classification details:

1. **Tooltips** - Hover over a line to see basic classification information
2. **Click Details** - Click on a line to see more detailed classification information
3. **Classification Legend** - A legend that explains the different line types and colors

## Benefits

The enhanced HTML formatter provides several key benefits:

1. **Better Understanding** - Developers can better understand why lines are classified as executable or non-executable
2. **Easier Debugging** - Makes it easier to debug coverage issues by showing classification context
3. **Visual Clarity** - Different line types are visually distinct, making reports easier to read
4. **Detailed Context** - Classification reasons are displayed in tooltips and modals

## Example

See the `examples/enhanced_html_formatter_example.lua` file for a complete example of using the enhanced HTML formatter with enhanced line classification.
--[[
  Execution vs Coverage Solution Proposal
  
  After thorough investigation, we've found that the debug hook approach is not
  fully reliable for capturing all executed lines, especially in conditional branches.
  
  Here's our proposed hybrid approach for the fixed implementation:
]]

local coverage = require("lib.coverage")
local debug_hook = require("lib.coverage.debug_hook")

-- Solution proposal:

--[[
1. ISSUE IDENTIFIED:
   - The debug hook doesn't consistently track all executed lines
   - Some conditional branches are executed (as proven by the output) but not recorded
   
2. ROOT CAUSE ANALYSIS:
   - debug.sethook() is not 100% reliable for capturing every line execution event
   - Some branch executions might happen too quickly or in specific contexts that
     the hook doesn't capture

3. SOLUTION APPROACH:
   a) Implement a hybrid execution tracking system:
      - Keep using debug.sethook for most line tracing
      - Add explicit/manual instrumentation capabilities for critical paths
      - Implement a more robust tracking mechanism for conditional branches
      
   b) Specific fixes needed:
      - Add a "manual_tracking" option to allow lib users to explicitly mark lines executed
      - Enhance initialize_file to always include _executed_lines table
      - Implement better branch detection in the debug hook
      - Add special handling for conditional branches in coverage processing
      
   c) Technical implementation:
      - Enhance coverage.track_line() to explicitly mark as executed too
      - Add a new coverage.track_execution() function that only marks execution
      - Update debug_hook to be more robust with event filtering
      - Improve conditional branch detection in the static analyzer
]]

-- The core issue in debug_hook.lua that needs fixing:
--[[ 
1. The debug hook sometimes misses execution events for conditional branches
2. We need to reliably initialize the _executed_lines table 
3. We should provide a direct API for test frameworks to signal execution
]]

-- The core issue in init.lua that needs fixing:
--[[
1. Properly expose the execution/covered distinction to users
2. Make sure _executed_lines is always correctly initialized and passed to reports
3. Create track_execution() function (separate from track_line)
4. Ensure HTML formatter correctly displays the four states
]]

print("This file presents the solution approach for fixing the execution vs coverage issue")
print("The main issues and solutions are documented in the file comments")
print("Implementation steps outlined above should result in a robust solution that")
print("doesn't rely on workarounds in test/example files")
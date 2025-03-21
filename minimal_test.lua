-- Simple test file to verify type annotations
local firmo = require("firmo")

-- Use the async module
if firmo.async then
    print("async module is available")
    
    -- Test async function
    local asyncFn = firmo.async(function() 
        return "Hello from async"
    end)
    
    local executor = asyncFn()
    local result = executor()
    print("Async result: " .. result)
    
    -- Test await (will error outside async context, which is expected)
    local ok, err = pcall(function()
        firmo.await(10)
    end)
    
    if not ok then
        print("Error from await (expected): " .. err)
    end
else
    print("async module is not available")
end

print("Test completed successfully")
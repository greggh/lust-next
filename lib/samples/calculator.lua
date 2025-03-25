-- Simple Calculator Module
-- Used for testing coverage functionality

local calculator = {}

function calculator.add(a, b)
    local result = a + b
    return result
end

function calculator.subtract(a, b)
    local result = a - b
    return result
end

function calculator.multiply(a, b)
    local result = a * b
    return result
end

function calculator.divide(a, b)
    if b == 0 then
        error("Division by zero")
    end
    local result = a / b
    return result
end

return calculator
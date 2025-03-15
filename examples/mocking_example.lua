-- Example demonstrating mocking functionality
package.path = "../?.lua;" .. package.path
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local mock, spy, stub, with_mocks = firmo.mock, firmo.spy, firmo.stub, firmo.with_mocks

-- A sample "database" module we'll use to demonstrate mocking
local database = {
  connect = function(db_name)
    -- In a real implementation, this would actually connect to a database
    print("Actually connecting to real database: " .. db_name)
    return {
      connected = true,
      name = db_name
    }
  end,
  
  query = function(db, query_string)
    -- In a real implementation, this would execute the query
    print("Actually executing query on " .. db.name .. ": " .. query_string)
    
    -- Simulate slow database access and potential errors
    if query_string:match("ERROR") then
      error("Database error: Invalid query")
    end
    
    return {
      rows = { {id = 1, name = "test"}, {id = 2, name = "sample"} },
      count = 2
    }
  end,
  
  disconnect = function(db)
    -- In a real implementation, this would disconnect
    print("Actually disconnecting from " .. db.name)
    db.connected = false
  end
}

-- A "user service" module that depends on the database
local UserService = {
  get_users = function()
    local db = database.connect("users")
    local result = database.query(db, "SELECT * FROM users")
    database.disconnect(db)
    return result.rows
  end,
  
  find_user = function(id)
    local db = database.connect("users")
    local result = database.query(db, "SELECT * FROM users WHERE id = " .. id)
    database.disconnect(db)
    return result.rows[1]
  end,
  
  create_user = function(user)
    local db = database.connect("users")
    local result = database.query(db, "INSERT INTO users (name) VALUES ('" .. user.name .. "')")
    database.disconnect(db)
    return {success = true, id = 3}  -- In a real implementation, this would be dynamic
  end
}

-- Examples demonstrating various mocking techniques
describe("Mocking Examples", function()
  
  describe("Basic Spy Functionality", function()
    it("tracks function calls", function()
      -- Create a simple spy on a function
      local fn = function(x) return x * 2 end
      local spied_fn = spy(fn)
      
      -- Call the function a few times
      spied_fn(5)
      spied_fn(10)
      
      -- Verify calls were tracked
      expect(spied_fn.call_count).to.equal(2)
      expect(spied_fn.calls[1][1]).to.equal(5)  -- First call, first argument
      expect(spied_fn.calls[2][1]).to.equal(10) -- Second call, first argument
    end)
    
    it("can spy on object methods", function()
      local calculator = {
        add = function(a, b) return a + b end,
        multiply = function(a, b) return a * b end
      }
      
      -- Spy on the add method
      local add_spy = spy(calculator, "add")
      
      -- Use the method
      local result = calculator.add(3, 4)
      
      -- Original functionality still works
      expect(result).to.equal(7)
      
      -- But calls are tracked
      expect(add_spy.called).to.be.truthy()
      expect(add_spy:called_with(3, 4)).to.be.truthy()
      
      -- Restore original method
      add_spy:restore()
    end)
  end)
  
  describe("Mock Object Functionality", function()
    it("can mock an entire object", function()
      -- Create a mock of the database object
      local db_mock = mock(database)
      
      -- Stub methods with our test implementations
      db_mock:stub("connect", function(name)
        return {name = name, connected = true}
      end)
      
      db_mock:stub("query", function()
        return {
          rows = {{id = 1, name = "mocked_user"}},
          count = 1
        }
      end)
      
      db_mock:stub("disconnect", function() end)
      
      -- Use the UserService which depends on the database
      local users = UserService.get_users()
      
      -- Verify our mocked data was returned
      expect(users[1].name).to.equal("mocked_user")
      
      -- Verify our mocks were called
      expect(db_mock._stubs.connect.called).to.be.truthy()
      expect(db_mock._stubs.query.called).to.be.truthy()
      expect(db_mock._stubs.disconnect.called).to.be.truthy()
      
      -- Verify the entire mock (all methods were called)
      expect(db_mock:verify()).to.be.truthy()
      
      -- Restore original methods
      db_mock:restore()
    end)
    
    it("can stub methods with return values", function()
      -- Create a mock and stub a method with a simple return value
      local db_mock = mock(database)
      
      -- Stub connect to return a simple value
      db_mock:stub("connect", {name = "test_db", connected = true})
      
      -- Call the stubbed method
      local connection = database.connect("any_name")
      
      -- The return value should be our stubbed value
      expect(connection.name).to.equal("test_db")
      
      -- Clean up
      db_mock:restore()
    end)
  end)
  
  describe("Using with_mocks Context Manager", function()
    it("automatically cleans up mocks", function()
      local original_connect = database.connect
      
      with_mocks(function(mock_fn)
        -- Create mock inside the context
        local db_mock = mock_fn(database)
        
        -- Stub methods
        db_mock:stub("connect", function() 
          return {name = "context_db", connected = true} 
        end)
        
        -- Use the mocked function
        local connection = database.connect("unused")
        expect(connection.name).to.equal("context_db")
        
        -- No need to restore - it happens automatically
      end)
      
      -- Outside the context, original function should be restored
      expect(database.connect).to.equal(original_connect)
    end)
    
    it("handles verification failures", function()
      local succeeded = pcall(function()
        with_mocks(function(mock_fn)
          local db_mock = mock_fn(database)
          db_mock:stub("connect", function() end)
          
          -- We don't call the stubbed method, which should fail verification
          db_mock:verify()
        end)
      end)
      
      expect(succeeded).to.equal(false)
    end)
  end)
  
  describe("Standalone Stub Functions", function()
    it("creates simple stubs", function()
      -- Create a standalone stub that returns a value
      local get_config = stub({debug = true, timeout = 1000})
      
      -- Use the stub
      local config = get_config()
      
      -- Check return value
      expect(config.debug).to.equal(true)
      expect(config.timeout).to.equal(1000)
      
      -- Verify the stub was called
      expect(get_config.called).to.be.truthy()
    end)
    
    it("can create function stubs", function()
      -- Create a stub with custom function behavior
      local validator = stub(function(value)
        return value > 0 and value < 100
      end)
      
      -- Use the stub
      local result1 = validator(50)
      local result2 = validator(150)
      
      -- Verify behavior
      expect(result1).to.equal(true)
      expect(result2).to.equal(false)
      
      -- Verify call tracking
      expect(validator.call_count).to.equal(2)
      expect(validator.calls[1][1]).to.equal(50)
      expect(validator.calls[2][1]).to.equal(150)
    end)
  end)
  
  describe("Real-world Example", function()
    it("tests UserService with mocked database", function()
      with_mocks(function(mock_fn)
        -- Create a mock for our database
        local db_mock = mock_fn(database)
        
        -- Stub all the methods
        db_mock:stub("connect", function(db_name)
          expect(db_name).to.equal("users")
          return {name = db_name, connected = true}
        end)
        
        db_mock:stub("query", function(db, query)
          expect(db.name).to.equal("users")
          expect(query).to.match("SELECT")
          
          return {
            rows = {{id = 999, name = "Test User"}},
            count = 1
          }
        end)
        
        db_mock:stub("disconnect", function(db)
          expect(db.name).to.equal("users")
        end)
        
        -- Now test our service
        local user = UserService.find_user(999)
        
        -- Verify the result
        expect(user.id).to.equal(999)
        expect(user.name).to.equal("Test User")
        
        -- Verify all expected calls were made
        expect(db_mock._stubs.connect:called_times(1)).to.be.truthy()
        expect(db_mock._stubs.query:called_times(1)).to.be.truthy()
        expect(db_mock._stubs.disconnect:called_times(1)).to.be.truthy()
        
        -- Verify mock as a whole
        db_mock:verify()
      end)
    end)
  end)
end)

print("\nMocking functionality examples completed!")

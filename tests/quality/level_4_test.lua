-- Test file for quality level 4
local firmo = require('firmo')
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe('Sample Test Suite', function()
  it('should perform basic assertion', function()
    expect(true).to.be.truthy()
    expect(1 + 1).to.equal(2)
  end)
  describe('Nested Group', function()
    it('should have multiple assertions', function()
      local value = 'test'
      expect(value).to.be.a('string')
      expect(#value).to.equal(4)
      expect(value:sub(1, 1)).to.equal('t')
    end)
  end)
  local setup_value = nil
  before(function()
    setup_value = 'initialized'
  end)
  after(function()
    setup_value = nil
  end)
  it('should use setup and mocking', function()
    expect(setup_value).to.equal('initialized')
    local mock = firmo.mock({ test = function() return true end })
    expect(mock.test()).to.be.truthy()
    expect(mock.test).to.have.been.called()
  end)
  describe('Edge Cases', function()
    it('should handle nil values', function()
      expect(nil).to.be.falsy()
      expect(function() return nil end).not.to.raise()
    end)
    it('should handle empty strings', function()
      expect('').to.be.a('string')
      expect(#'').to.equal(0)
    end)
    it('should handle large numbers', function()
      expect(1e10).to.be.a('number')
      expect(1e10 > 1e9).to.be.truthy()
    end)
  end)
end)

return true

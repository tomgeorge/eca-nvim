local MiniTest = require("mini.test")
local H = {}

H.expect_contains_message = MiniTest.new_expectation("Contains message", function(messages, pattern)
  local m = vim
    .iter(messages)
    :filter(function(m)
      return m.content:find(pattern) ~= nil
    end)
    :totable()
  return #m > 0
end, function(messages, str)
  return string.format("Pattern %s\nnot found in %s", str, vim.inspect(messages))
end)

H.expect_match = MiniTest.new_expectation("string matching", function(str, pattern)
  return str:find(pattern) ~= nil
end, function(str, pattern)
  return string.format("Pattern: %s\nObserved string: %s", vim.inspect(pattern), str)
end)

H.expect_no_match = MiniTest.new_expectation("string not matching", function(str, pattern)
  return str:find(pattern) == nil
end, function(str, pattern)
  return string.format("Pattern: %s\nObserved string: %s", vim.inspect(pattern), str)
end)

return H

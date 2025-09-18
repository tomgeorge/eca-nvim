---@class eca.Mediator
---@field server eca.Server
local mediator = {}

---@param server eca.Server
---@return eca.Mediator
function mediator.new(server)
  return setmetatable({
    server = server,
  }, { __index = mediator })
end

---@param method string
---@param params eca.MessageParams
---@param callback? fun(err?: string, result?: table)
function mediator:send(method, params, callback)
  if not self.server:is_running() then
    if callback then
      callback("Server is not running, please start the server", nil)
    end
    require("eca.logger").notify("Server is not rnning, please start the server", vim.log.levels.WARN)
  end
  self.server:send_request(method, params, callback)
end

return mediator

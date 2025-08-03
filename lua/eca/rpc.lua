---@class eca.RPC
---@field private _id_counter integer
---@field private _pending_requests table<integer, function>
---@field private _job_id any
---@field private _on_notification function?
---@field private _buffer string
local M = {}
M.__index = M

---@param job_id any vim.fn.jobstart job ID
---@return eca.RPC
function M:new(job_id)
  local instance = setmetatable({}, M)
  instance._id_counter = 0
  instance._pending_requests = {}
  instance._job_id = job_id
  instance._on_notification = nil
  instance._buffer = ""
  return instance
end

---@param callback function
function M:on_notification(callback)
  self._on_notification = callback
end

---@return integer
function M:_next_id()
  self._id_counter = self._id_counter + 1
  return self._id_counter
end

---@param obj table
---@return string
function M:_encode_json(obj)
  return vim.json.encode(obj)
end

---@param json string
---@return table
function M:_decode_json(json)
  local ok, result = pcall(vim.json.decode, json)
  if ok then
    return result
  else
    error("Failed to decode JSON: " .. tostring(result))
  end
end

---@param message table
function M:_send_message(message)
  local json = self:_encode_json(message)
  local content = string.format("Content-Length: %d\r\n\r\n%s", #json, json)
  
  if self._job_id and self._job_id > 0 then
    -- Use vim.fn.chansend to send data to the job's stdin
    vim.fn.chansend(self._job_id, content)
  end
end

---@param method string
---@param params table
---@param callback function?
---@return integer? request_id
function M:send_request(method, params, callback)
  local id = self:_next_id()
  
  local message = {
    jsonrpc = "2.0",
    id = id,
    method = method,
    params = params or {}
  }
  
  if callback then
    self._pending_requests[id] = callback
  end
  
  self:_send_message(message)
  return id
end

---@param method string
---@param params table?
function M:send_notification(method, params)
  local message = {
    jsonrpc = "2.0",
    method = method,
    params = params or {}
  }
  
  self:_send_message(message)
end

---@param data string
function M:_process_message(data)
  local ok, message = pcall(self._decode_json, self, data)
  if not ok then
    return
  end
  
  if message.id and self._pending_requests[message.id] then
    -- This is a response to a request
    local callback = self._pending_requests[message.id]
    self._pending_requests[message.id] = nil
    
    if message.error then
      callback(message.error, nil)
    else
      callback(nil, message.result)
    end
  elseif message.method and not message.id then
    -- This is a notification
    if self._on_notification then
      self._on_notification(message.method, message.params)
    end
  end
end

---@param buffer string
---@return string[] messages, string remaining_buffer
function M:_parse_messages(buffer)
  local messages = {}
  local remaining = buffer
  
  while true do
    -- Look for Content-Length header
    local content_length_start, content_length_end = remaining:find("Content%-Length: (%d+)")
    if not content_length_start then
      break
    end
    
    local length_str = remaining:match("Content%-Length: (%d+)")
    local content_length = tonumber(length_str)
    if not content_length then
      break
    end
    
    -- Find the end of headers (double CRLF)
    local headers_end = remaining:find("\r\n\r\n", content_length_end)
    if not headers_end then
      break
    end
    
    local content_start = headers_end + 4
    local content_end = content_start + content_length - 1
    
    if #remaining < content_end then
      -- Not enough data for complete message
      break
    end
    
    local content = remaining:sub(content_start, content_end)
    table.insert(messages, content)
    
    remaining = remaining:sub(content_end + 1)
  end
  
  return messages, remaining
end

---@param data string
function M:_handle_stdout(data)
  self._buffer = self._buffer .. data
  local messages, remaining = self:_parse_messages(self._buffer)
  self._buffer = remaining
  
  for _, message in ipairs(messages) do
    self:_process_message(message)
  end
end

function M:stop()
  -- Clear pending requests
  for id, callback in pairs(self._pending_requests) do
    callback("Connection closed", nil)
  end
  self._pending_requests = {}
  
  -- Stop the job if it's still running
  if self._job_id and self._job_id > 0 then
    vim.fn.jobstop(self._job_id)
  end
end

return M

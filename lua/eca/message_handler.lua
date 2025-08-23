local M = {}

--- Parse raw messages coming from the ECA server
---@param data string
---@return {content_length: integer, content: string}[]
function M.parse_raw_messages(data)
  local messages = {}
  local seek_head = 1
  while true do
    local first, last, capture = string.find(data, "Content%-Length: (%d+)[\r\n]+", seek_head)
    if not first then
      break
    end
    capture = tonumber(capture)
    seek_head = last + capture
    table.insert(messages, { content_length = capture, content = string.sub(data, last + 1, seek_head) })
  end
  return messages
end

return M

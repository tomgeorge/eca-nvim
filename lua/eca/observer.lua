local observer = {}

---@type { [integer]: fun(message: table) }
local subscriptions = {}

---@param id integer
---@param on_update fun(message: table)
function observer.subscribe(id, on_update)
  subscriptions[id] = on_update
end

function observer.unsubscribe(id)
  if subscriptions[id] then
    subscriptions[id] = nil
  end
end

function observer.notify(message)
  for _, fn in pairs(subscriptions) do
    fn(message)
  end
end

return observer

-- Written by Marijke and Barna
local libsocket = require("socket")

local minipc = {}

minipc.ip = "127.0.0.1"
minipc.port = 6969

-- default log
function minipc.log(message)
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  print("[" .. timestamp .. "]: " .. message)
end

-- log secret values
function minipc.sec(message)
  if (arg[2] or arg[1]) ~= "sec" then return end
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  print("{" .. timestamp .. "}: " .. message)
end

-- retry wrapper for robust calls
-- sockets are sometimes prone to timing
-- errors, this makes it easy to use them
function minipc.retry(task, retries, delay)
  retries = retries or 4
  delay = delay or 1

  -- retry mechanism
  for attempt = 1, retries do
    local success, result = pcall(task)
    if success then
      return result
    else
      if attempt < retries then
        os.execute("sleep " .. delay)
        delay = delay * 1.5
      end
    end
  end

  -- chrash code, something is up
  error("* task failed after multiple retries")
end

-- TODO: async
-- serve message to socket for n clients
function minipc:serve(message, broadcast, callback)
  -- default to one-to-one
  broadcast = broadcast or 1

  -- init tcp object as server
  local server, binerr = libsocket.bind(self.ip, self.port)
  if binerr or not server then
    error("* failed to create server: " .. binerr)
    return
  end

  -- shutdown method
  local clients = {}
  local function shutdown()
    minipc.log("served data on " .. self.ip .. ":" .. self.port .. " for " .. broadcast)
    for _, client in ipairs(clients) do client:close() end
    server:close()
  end

  -- accept clients
  self.log("waiting on participants")
  for _ = 1, broadcast do
    local client, accerr = server:accept()
    if accerr or not client then
      error("* failed to accept client: " .. accerr)
    end
    table.insert(clients, client)
  end

  -- serve clients with data
  if callback ~= nil then
    callback(clients, message)
  else
    for _, client in ipairs(clients) do
      local bytes, snderr, _ = client:send(tostring(message) .. "\n")
      if snderr or not bytes then
        error("* failed to send message: " .. snderr)
      end
    end
  end

  -- shutdown
  shutdown()
end

-- eat one message from socket
function minipc:eat(callback)
  -- init tcp object
  local client, tcperr = libsocket.tcp()
  if tcperr or not client then
    error("* failed to create client")
  end

  -- connect to server
  local status, conerr = client:connect(self.ip, self.port)
  if conerr or not status then
    client:close()
    error("* failed to connect: " .. conerr)
  end

  -- read message from server
  local data = nil
  if callback ~= nil then
    data = callback(client)
  else
    local recerr = nil
    data, recerr, _ = client:receive()
    if recerr or not data then
      client:close()
      error("* failed to read: " .. recerr)
    end
  end

  minipc.log("read from " .. self.ip .. ":" .. self.port)

  client:close()
  return data
end

return minipc


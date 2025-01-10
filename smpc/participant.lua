local libsocket = require("socket")

local function listen()
  -- open tcp socket
  local socket = assert(libsocket.bind("127.0.0.1", 24242))
  local ip, port = socket:getsockname()
  print("> listening on " .. ip .. " port " .. port)

  -- accept incoming connection
  local sender = socket:accept()

  -- receive message
  local msg, err = sender:receive()
  if not err then
    print("> received message: " .. msg)
  else
    print("* failed to receive the message: " .. err)
  end

  socket:close()
end

local function send(message)
  -- create tcp object
  local socket = assert(libsocket.tcp())

  -- connect to socket
  local ip, port = "127.0.0.1", 24242
  local success, err = socket:connect(ip, port)
  if not success then
    print("* failed to connect socket: " .. err)
    return
  else
    print("> connected to " .. ip .. " on port " .. port)
  end

  -- send message to socket
  local bytes, senderr = socket:send(message .. "\n")
  if not senderr then
    print("> sent " .. string.format("%d", bytes) .. " bytes: " .. message)
  else
    print("* failed to send message: " .. senderr)
  end

  socket:close()
end

if arg[1] == "send" then
  send(arg[2])
elseif arg[1] == "listen" then
  listen()
else
  print("Invalid parameters")
end


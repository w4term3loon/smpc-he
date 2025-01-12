local libsocket = require("socket")

-- default log
local function log(message)
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  print("[" .. timestamp .. "]: " .. message)
end

-- log secret values
local function sec(message)
  if (arg[2] or arg[1]) ~= "sec" then return end
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  print("{" .. timestamp .. "}: " .. message)
end

-- retry wrapper for robust calls
local function retry(task, retries, delay)
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
local function serve(ip, port, message, broadcast, callback)
  -- default to one-to-one
  broadcast = broadcast or 1

  -- init tcp object as server
  local server, binerr = libsocket.bind(ip, port)
  if binerr or not server then
    error("* failed to create server: " .. binerr)
    return
  end

  -- shutdown method
  local clients = {}
  local function shutdown()
    log("served data on " .. ip .. ":" .. port .. " for " .. broadcast)
    for _, client in ipairs(clients) do client:close() end
    server:close()
  end

  -- accept clients
  log("waiting on participants")
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
local function eat(ip, port, callback)
  -- init tcp object
  local client, tcperr = libsocket.tcp()
  if tcperr or not client then
    error("* failed to create client")
  end

  -- connect to server
  local status, conerr = client:connect(ip, port)
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

  log("read from " .. ip .. ":" .. port)

  client:close()
  return data
end

-- master
-- format public parameters
local function formatPublic(weights)
  local string = ""
  for _, w in ipairs(weights) do
    string = string .. w .. ":"
  end
  string = string:sub(1, #string - 1)
  return string
end

-- slave
-- extract public parameters
local function processPublic(public)
  local weights = {}
  local processID = tonumber(public:match("([^/]+)"))
  public = public:gsub("%d+/", "")
  for c in public:gmatch("([^:]+)") do
    table.insert(weights, c)
  end
  return weights, processID
end

local function setup(ip, port, headcount)
  -- try to bind it as server
  local temp, tmperr = libsocket.bind(ip, port)
  local callback = function(clients, message)
    for i, client in ipairs(clients) do
      local bytes, snderr, _ = client:send(tostring(i + 1) .. "/" .. tostring(message) .. "\n")
      if snderr or not bytes then
        error("* failed to send message: " .. snderr)
      end
    end
  end

  -- master
  if temp and not tmperr then
    log("starting setup as master")

    temp:close()
    local weights = {}
    headcount = headcount or 3

    -- create weights
    for _ = 1, headcount do
      table.insert(weights, math.random(1, 10))
    end

    -- serve slaves with data
    local processID = 1
    local public = formatPublic(weights)
    serve(ip, port, public, headcount - 1, callback)
    log("public parameters are sent to participants")

    -- return headcount
    return weights, headcount, processID
  else
    log("joining setup as slave")
    -- connect to master
    local public = retry(function() return eat(ip, port) end)

    -- process public parameters
    -- TODO: check validity
    local weights, processID = processPublic(public)
    log("received public parameters [pid/weights]: " .. public)

    -- return headcount and pid
    return weights, #weights, processID
  end
end

-- generate shares form secret
local function generateShares(secret, public, headcount)
  log("generating shares from secret")
  local sum = 0
  local shares = {}
  -- generate n-1 random shares
  for _ = 1, headcount - 1 do
    local share = math.random(0, public["prime"] - 1)
    sec("generated share " .. share)
    table.insert(shares, share)
    sum = (sum + share) % public["prime"]
  end

  -- compute the final share to ensure the sum is secret mod prime
  local lastShare = (secret - sum) % public["prime"]
  table.insert(shares, lastShare)
  sec("final share is " .. lastShare)

  log("private shares are generated")
  return shares
end

local function distributeShares(ip, port, processID, shares, headcount)
  log("distributing private shares")
  local collectedShares = {}
  for token = 1, headcount do
    if token == processID then
      -- callback
      local masterCb = function(clients, _)
        for i, client in ipairs(clients) do
          local share = shares[i]
          local bytes, snderr, _ = client:send(processID .. "/" .. tostring(share) .. "\n")
          if snderr or not bytes then
            error("* failed to send message: " .. snderr)
          end
        end
      end

      -- call server function
      serve(ip, port, shares, headcount - 1, masterCb)
      collectedShares[processID] = shares[processID]
    else
      -- callback
      local slaveCb = function(client)
        local data, recerr, _ = client:receive()
        if recerr or not data then
          client:close()
          error("* failed to read: " .. recerr)
        end

        -- parse the return value
        for pid, share in string.gmatch(data, "(%d+)/(%d+)") do
          return pid, share -- TODO: verify data
        end
      end

      -- call client function
      local pid, share = retry(function()
        return eat(ip, port, slaveCb)
      end)

      -- store received data
      -- TODO: maybe closure
      collectedShares[pid] = tonumber(share)
    end
  end

  log("private shares are distributed")
  return collectedShares
end

-- calcualte partial sum from shares
local function calculatePartialSum(collectedShares, public)
  log("calculating partial sum with collected shares")
  local partialSum = 0
  for i, share in ipairs(collectedShares) do
    partialSum = partialSum + share * public["weights"][i]
    partialSum = partialSum % public["prime"]
  end

  log("partial sum is calculated")
  return partialSum
end

-- serve partial sum to all participants
local function distributePartialSum(ip, port, processID, partialSum, headcount)
  log("distributing partial sums")
  local partialSums = {}
  for token = 1, headcount do
    if token == processID then
      serve(ip, port, partialSum, headcount - 1)
      table.insert(partialSums, partialSum)
      log("partial sum is revealed")
    else
      -- connect to master
      local partial = retry(function() return eat(ip, port) end)
      table.insert(partialSums, tonumber(partial))
      log("received partial sum from " .. token)
    end
  end

  log("partial sums are distributed")
  return partialSums
end

-- calculate weighted sum from partial sums
local function calculateWeightedSum(partialSums, public)
  log("calculating weighted sum")
  local weightedSum = 0
  for _, s in ipairs(partialSums) do
    weightedSum = weightedSum + s
    weightedSum = weightedSum % public["prime"]
  end

  log("weighted sum is calculated")
  return weightedSum
end

-- main skeleton for communication
local function protocol(ip, port)
  -- public parameters
  local public = {}
  local headcount, processID = nil, nil
  math.randomseed(os.time())

  -- initialize public parameters
  public["prime"] = 2 ^ 31 - 1 -- Mersenne prime
  public["weights"], headcount, processID = setup(ip, port, tonumber(arg[1]))

  -- generate secret
  math.randomseed(os.time() + processID)
  local secret = math.random(0, public["prime"] - 1)
  sec("prime used for protocol is " .. public["prime"])
  sec("generated secret is " .. secret)

  -- generate and distribute shares
  local shares = generateShares(secret, public, headcount)
  local collectedShares = distributeShares(ip, port, processID, shares, headcount)

  -- calculate and distribute partial sum
  local partialSum = calculatePartialSum(collectedShares, public)
  local collectedPartialSums = distributePartialSum(ip, port, processID, partialSum, headcount)

  -- calculate weighted sum
  local weightedSum = calculateWeightedSum(collectedPartialSums, public)
  log("weighted sum: " .. weightedSum)
end

-- start protocol
protocol("127.0.0.1", 53709)

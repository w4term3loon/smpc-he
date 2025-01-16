local ipc = dofile("../minipc.lua")

local pallier = require("pallier")
local tools = require("tools")

local bob = {}

function bob.unpack(msg, delim)
  delim = delim or ":"
  local unpack = {}
  for s in msg:gmatch("([^" .. delim .. "]+)") do
    table.insert(unpack, s)
  end
  return unpack
end

function bob:setup()
  -- eat public params
  local public = self.unpack(ipc.retry(function()
    return ipc:eat()
  end))

  -- init bob with n, g
  local n, g = tonumber(public[1]), tonumber(public[2])
  pallier:initbob(n, g)

  -- gen vec
  self.dim = tonumber(ipc.retry(function()
    return ipc:eat()
  end))
  self.vec = tools.genVec(self.dim, pallier.n)
  ipc.log("vec is: " .. tools.formatVec(self.vec))
end

function bob:beaver()
  -- eat alice beaver share
  local unpack = self.unpack(ipc.retry(function()
    return ipc:eat()
  end))
  self.enc_alice_x = tonumber(unpack[1])
  self.enc_alice_y = tonumber(unpack[2])

  -- gen random beaver shares
  self.x = math.random(0, pallier.n - 1)
  self.y = math.random(0, pallier.n - 1)

  -- x_A * y_B
  self.enc_xy = tools.modularExp(self.enc_alice_x, self.y, pallier.n_squared)

  -- y_A * x_B
  self.enc_yx = tools.modularExp(self.enc_alice_y, self.x, pallier.n_squared)

  -- added random
  self.r = math.random(0, pallier.n - 1)
  self.enc_r = pallier:encrypt(self.r)

  -- x_A * y_B + y_A * x_B + r
  self.enc_xy_yx_r = (self.enc_xy * self.enc_yx * self.enc_r) % pallier.n_squared

  -- send it to alice
  ipc.retry(function()
    return ipc:serve(self.enc_xy_yx_r)
  end)

  -- beaver product share
  self.z = self.x * self.y - self.r

  ipc.log("beaver triplets shared")
end

function bob:de(com)
  self.enc_e_share = pallier:encrypt(com - self.y)

  -- eat alice's share
  self.enc_d_share = tonumber(ipc.retry(function()
    return ipc:eat()
  end))

  -- serve share to alice
  ipc.retry(function()
    return ipc:serve(self.enc_e_share)
  end)

  -- calculate d
  self.enc_d = (self.enc_d_share * pallier:encrypt((-1) * self.x)) % pallier.n_squared

  -- serve d to alice
  ipc.retry(function()
    return ipc:serve(self.enc_d)
  end)

  -- eat d and e
  local de = self.unpack(ipc.retry(function()
    return ipc:eat()
  end))
  self.d = tonumber(de[1])
  self.e = tonumber(de[2])

  ipc.log("de: " .. self.d .. ":" .. self.e)
end

function bob:addw()
  -- final product share
  self.w = self.w or 0
  self.w = (self.w + self.d * self.y + self.e * self.x + self.z) % pallier.n
end

function bob:mul()
  self.enc_w = pallier:encrypt(self.w) -- ?

  -- serve w to alice
  ipc.retry(function()
    return ipc:serve(self.enc_w)
  end)

  -- eat mul
  self.mul = tonumber(ipc.retry(function()
    return ipc:eat()
  end))

  ipc.log("mul is: " .. self.mul)
end

function bob:iterate()
  for _, com in ipairs(self.vec) do
    self:beaver()
    self:de(com)
    self:addw()
  end
end

local function protocol(ip, port)
  ipc.ip = ip
  ipc.port = port

  math.randomseed(os.time())

  bob:setup()
  bob:iterate()
  bob:mul()
end

protocol("127.0.0.1", 44242)

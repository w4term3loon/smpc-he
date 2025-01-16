local ipc = dofile("../minipc.lua")

local pallier = require("pallier")
local tools = require("tools")

local alice = {}

function alice.pack(msg)
  local pack = ""
  for _, elem in ipairs(msg) do
    pack = pack .. elem .. ":"
  end
  return pack:sub(1, #pack - 1)
end

function alice:setup()
  -- init alice with p, q
  pallier:initalice(13, 73)

  -- share n
  ipc.retry(function()
    return ipc:serve(self.pack({ pallier.n, pallier.g }))
  end)

  -- gen vec
  ipc.retry(function()
    return ipc:serve(self.dim)
  end)
  self.vec = tools.genVec(self.dim, pallier.n)
  ipc.log("vec is: " .. tools.formatVec(self.vec))
end

function alice:beaver()
  -- random beaver shares
  self.x = math.random(0, pallier.n - 1)
  self.y = math.random(0, pallier.n - 1)
  self.enc_x = pallier:encrypt(self.x)
  self.enc_y = pallier:encrypt(self.y)

  -- pack and send msg
  local pack = self.pack({ self.enc_x, self.enc_y })
  ipc.retry(function()
    return ipc:serve(pack)
  end)

  -- bob shares calculation
  self.enc_xy_yx_r = tonumber(ipc.retry(function()
    return ipc:eat()
  end))
  self.z = (self.x * self.y + pallier:decrypt(self.enc_xy_yx_r)) % pallier.n
  ipc.log("beaver triplets shared")
end

function alice:de(com)
  self.enc_d_share = pallier:encrypt(com - self.x)

  -- serve share to bob
  ipc.retry(function()
    return ipc:serve(self.enc_d_share)
  end)

  -- eat bob's share
  self.enc_e_share = tonumber(ipc.retry(function()
    return ipc:eat()
  end))

  -- eat bob's d (xd)
  self.enc_d = tonumber(ipc.retry(function()
    return ipc:eat()
  end))

  -- calculate d and e
  self.d = pallier:decrypt(self.enc_d)
  self.e = (pallier:decrypt(self.enc_e_share) - self.y) % pallier.n

  -- public params
  -- TODO: could be encrypted since bob could
  -- make use of the homomorphism of pallier (?)
  ipc.retry(function()
    return ipc:serve(self.pack({ self.d, self.e }))
  end)

  ipc.log("de: " .. self.d .. ":" .. self.e)
end

function alice:addw()
  -- alice's final share
  self.w = self.w or 0
  self.w = (self.w + self.d * self.e + self.d * self.y + self.e * self.x + self.z) % pallier.n
end

function alice:mul()
  -- bob's final share
  self.enc_bob_w = tonumber(ipc.retry(function()
    return ipc:eat()
  end))
  self.bob_w = pallier:decrypt(self.enc_bob_w)

  self.mul = (self.w + self.bob_w) % pallier.n
  ipc.retry(function()
    return ipc:serve(self.mul)
  end)

  ipc.log("mul is: " .. self.mul)
end

function alice:iterate()
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

  alice.dim = arg[1] or 3
  alice:setup()
  alice:iterate()
  alice:mul()
end

protocol("127.0.0.1", 44242)


local tools = require("tools")

local pallier = {}

function pallier:initalice(p, q)
  self.p = p or 23 -- default
  self.q = q or 73 -- default
  self.n = self.p * self.q
  self.n_squared = self.n * self.n
  self.lam = tools:lcm(self.p - 1, self.q - 1)
  self.g = self.n + 1
end

function pallier:initbob(n, g)
  self.n = n
  self.n_squared = self.n * self.n
  self.g = g
end

function pallier:L(x)
  return math.floor((x - 1) / self.n)
end

function pallier:encrypt(m)
  m = m % self.n

  local r = math.random(2, self.n - 1)
  while tools.gcd(r, self.n) ~= 1 do
    r = math.random(2, self.n - 1)
  end

  -- Calculate c = (g^m * r^n) mod n^2
  local g_m = tools.modularExp(self.g, m, self.n_squared)
  local r_n = tools.modularExp(r, self.n, self.n_squared)
  return (g_m * r_n) % self.n_squared
end

function pallier:decrypt(c)
  local c_lambda = tools.modularExp(c, self.lam, self.n_squared)
  local L_c = self:L(c_lambda)

  local g_lambda = tools.modularExp(self.g, self.lam, self.n_squared)
  local L_g = self:L(g_lambda)

  -- Use modular multiplicative inverse instead of division
  local mu = tools.modInverse(L_g, self.n)
  return (L_c * mu) % self.n
end

function pallier:print()
  print("Pallier parameters:")
  print("p: " .. (self.p or "nil"))
  print("q: " .. (self.q or "nil"))
  print("n: " .. self.n)
  print("n^2: " .. self.n_squared)
  print("lam: " .. (self.lam or "nil"))
  print("g: " .. self.g)
end

return pallier

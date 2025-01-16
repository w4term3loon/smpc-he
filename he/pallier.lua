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

  -- c = (g^m * r^n) mod n^2
  local g_m = tools.modularExp(self.g, m, self.n_squared)
  local r_n = tools.modularExp(r, self.n, self.n_squared)
  return (g_m * r_n) % self.n_squared
end

function pallier:decrypt(c)
  local c_lambda = tools.modularExp(c, self.lam, self.n_squared)
  local L_c = self:L(c_lambda)

  local g_lambda = tools.modularExp(self.g, self.lam, self.n_squared)
  local L_g = self:L(g_lambda)

  -- use modular multiplicative inverse instead of division
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


local function test_basic()
  print("\nBasic encryption/decryption test:")
  local m = 42
  local c = pallier:encrypt(m)
  local d = pallier:decrypt(c)
  print("Original:", m)
  print("Decrypted:", d)
  assert(m == d, "Basic encryption/decryption failed")
end

local function test_addition()
  print("\nHomomorphic addition test:")
  local m1 = 30
  local m2 = 40
  print("m1:", m1)
  print("m2:", m2)

  local c1 = pallier:encrypt(m1)
  local c2 = pallier:encrypt(m2)

  local c_sum = (c1 * c2) % pallier.n_squared
  local sum = pallier:decrypt(c_sum)

  print("Decrypted sum:", sum)
  assert(sum == (m1 + m2) % pallier.n, "Homomorphic addition failed")
end

local function test_mult_constant()
  print("\nHomomorphic multiplication by constant test:")
  local m = 30
  local k = 40
  print("m:", m)
  print("k:", k)

  local c = pallier:encrypt(m)
  local c_mult = tools.modularExp(c, k, pallier.n_squared)
  local result = pallier:decrypt(c_mult)

  print("Decrypted result:", result)
  assert(result == (m * k) % pallier.n, "Homomorphic multiplication failed")
end

function pallier:test()
  test_basic()
  test_addition()
  test_mult_constant()
end

return pallier

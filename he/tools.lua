local tools = {}

function tools.gcd(a, b)
  while b ~= 0 do
    a, b = b, a % b
  end
  return math.abs(a)
end

function tools:lcm(a, b)
  return math.abs(a * b) // self.gcd(a, b)
end

function tools.modularExp(base, exponent, modulus)
  if modulus == 1 then
    return 0
  end

  local result = 1
  base = base % modulus

  while exponent > 0 do
    if exponent % 2 == 1 then
      result = (result * base) % modulus
    end
    base = (base * base) % modulus
    exponent = math.floor(exponent / 2)
  end

  return result
end

function tools.modInverse(a, m)
  local m0, x0, x1 = m, 0, 1

  while a > 1 do
    local q = math.floor(a / m)
    a, m = m, a % m
    x0, x1 = x1 - q * x0, x0
  end

  if x1 < 0 then
    x1 = x1 + m0
  end

  return x1
end

function tools.genVec(dim, n)
  local vec = {}
  for i = 1, dim do
    vec[i] = math.random(0, n - 1)
  end
  return vec
end

function tools.formatVec(vec)
  local out = "["
  for _, v in ipairs(vec) do
    out = out .. v .. ", "
  end
  return (out:sub(1, #out - 2) .. "]")
end

return tools

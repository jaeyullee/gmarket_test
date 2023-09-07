local json = require "cjson"

local alg = require "alg"
local alg_verify = alg.alg_verify
local alg_sign = alg.alg_sign

local rep = string.rep
local find = string.find
local insert = table.insert
local concat = table.concat
local sub = string.sub
local decode_base64 = ngx.decode_base64
local encode_base64 = ngx.encode_base64
local time = ngx.time
local type = type
local pairs = pairs
local error = error
local pcall = pcall
local unpack = unpack
local tostring = tostring
local setmetatable = setmetatable
local getmetatable = getmetatable

local _M = {}
_M.__index = _M

local function base64_decode(input)
  local remainder = #input % 4

  if remainder > 0 then
    local padlen = 4 - remainder
    input = input .. rep("=", padlen)
  end

  input = input:gsub("-", "+"):gsub("_", "/")

  return decode_base64(input)
end

function _M.base64_decode(input)
  return base64_decode(input)
end

local function tokenize(str, div, len)
  local result, pos = {}, 0

  local iter = function()
    return find(str, div, pos, true)
  end

  for st, sp in iter do
    result[#result + 1] = sub(str, pos, st-1)
    pos = sp + 1
    len = len - 1
    if len <= 1 then
      break
    end
  end

  result[#result + 1] = sub(str, pos)

  return result
end

local function decode_token(token)
  -- Get b64 parts
  local header_64, claims_64, signature_64 = unpack(tokenize(token, ".", 3))

  -- Decode JSON
  local ok, header, claims, signature = pcall(function()
    return json.decode(base64_decode(header_64)), json.decode(base64_decode(claims_64)), base64_decode(signature_64)
  end)
  if not ok then
    -- return nil, "invalid JSON"
    return nil, "4"
  end

  if not header.alg or type(header.alg) ~= "string" or not alg_verify[header.alg] then
    -- return nil, "invalid alg"
    return nil, "5"
  end

  if not claims then
    -- return nil, "invalid claims"
    return nil, "6"
  end

  if not signature then
    -- return nil, "invalid signature"
    return nil, "7"
  end

  return {
    token = token,
    header_64 = header_64,
    claims_64 = claims_64,
    signature_64 = signature_64,
    header = header,
    claims = claims,
    signature = signature
  }
end

-- For test purposes
local function base64_encode(input)
  local result = encode_base64(input, true)
  result = result:gsub("+", "-"):gsub("/", "_")
  return result
end

-- For test purposes
function _M.base64_encode(input)
  return base64_encode(input)
end

-- For test purposes
local function encode_token(claims, key, header)
  if type(claims) ~= "table" then
    error("Argument #1 must be table", 2)
  end

  if type(key) ~= "string" then
    error("Argument #2 must be string", 2)
  end

  if header and type(header) ~= "table" then
    error("Argument #3 must be a table", 2)
  end

  local new_alg = header.alg or "HS256"

  if not alg_sign[new_alg] then
    error("Algorithm not supported", 2)
  end

  local new_header = header or { typ = "JWT", alg = new_alg }
  local segments = {
    base64_encode(json.encode(new_header)),
    base64_encode(json.encode(claims))
  }

  local signing_input = concat(segments, ".")
  local signature = alg_sign[new_alg](signing_input, key)

  segments[#segments+1] = base64_encode(signature)

  return concat(segments, ".")
end

-- For test purposes
_M.encode_token = encode_token

function _M.new(token)
  if type(token) ~= "string" then
    error("Token must be a string, got " .. tostring(token), 2)
  end

  local _token, err = decode_token(token)
  if err then
    return nil, err
  end

  return setmetatable(_token, _M)
end

function _M:verify_signature(key)
  return alg_verify[self.header.alg](self.header_64 .. "." .. self.claims_64, self.signature, key)
end

local err_list_mt = {}


local function add_error(errors, k, v)
  if not errors then
    errors = {}
  end

  if errors and errors[k] then
    if getmetatable(errors[k]) ~= err_list_mt then
      errors[k] = setmetatable({errors[k]}, err_list_mt)
    end

    insert(errors[k], v)
  else
    errors[k] = v
  end

  return errors
end

--- Registered claims according to RFC 7519 Section 4.1
local registered_claims = {
  nbf = {
    type = "number",
    check = function(nbf)
      if nbf > time() then
        -- return "token not valid yet"
        return "ER012"
      end
    end
  },
  exp = {
    type = "number",
    check = function(exp)
      if exp <= time() then
        -- return "token expired"
        return "ER013"
      end
    end
  }
}

function _M:verify_registered_claims(claims_to_verify)
  if not claims_to_verify then
    claims_to_verify = {}
  end

  local errors
  local claim
  local claim_rules

  for _, claim_name in pairs(claims_to_verify) do
    claim = self.claims[claim_name]
    claim_rules = registered_claims[claim_name]

    if type(claim) ~= claim_rules.type then
      -- errors = add_error(errors, claim_name, "must be a " .. claim_rules.type)
      errors = add_error(errors, claim_name, "ER004")
    else
      local check_err = claim_rules.check(claim)
      if check_err then
        errors = add_error(errors, claim_name, check_err)
      end
    end
  end

  return errors == nil, errors
end

function _M:check_maximum_expiration(maximum_expiration)
  if maximum_expiration <= 0 then
    return true
  end

  local exp = self.claims.exp
  if exp == nil or exp - time() > maximum_expiration then
    -- return false, { exp = "exceeds maximum allowed expiration" }
    return false, { exp = "ER011" }
  end

  return true
end

return _M

local json = require "cjson"
local db = require "db"
local util = require "util"
local jwt_parser = require "jwt_parser"

local fmt = string.format
local error = error
local tostring = tostring
local type = type
local ngx = ngx
local retrieve_token = util.retrieve_token
local set_consumer = util.set_consumer

local _M = {}
_M.__index = _M

local function do_authentication(config)
  local conf = config.conf
  local token, err = retrieve_token(conf)
  if err then
    return error(err)
  end

  local token_type = type(token)
  if token_type ~= "string" then
    if token_type == "nil" then
      -- return false, { status = 401, message = "Unauthorized" }
      return false, { status = 401, message = "ER001" }
    elseif token_type == "table" then
      -- return false, { status = 401, message = "Multiple tokens provided" }
      return false, { status = 401, message = "ER002" }
    else
      -- return false, { status = 401, message = "Unrecognizable token" }
      return false, { status = 401, message = "ER003" }
    end
  end

  -- Decode token to find out who the consumer is
  local jwt, token_err = jwt_parser.new(token)
  if token_err then
    -- return false, { status = 401, message = "Bad token; " .. tostring(token_err) }
    return false, { status = 401, message = "ER01" .. tostring(token_err) }
  end

  local claims = jwt.claims
  local header = jwt.header

  local jwt_secret_key = claims[conf.key_claim_name] or header[conf.key_claim_name]
  if not jwt_secret_key then
    -- return false, { status = 401, message = "No mandatory '" .. conf.key_claim_name .. "' in claims" }
    return false, { status = 401, message = "ER005" }
  elseif jwt_secret_key == "" then
    -- return false, { status = 401, message = "Invalid '" .. conf.key_claim_name .. "' in claims" }
    return false, { status = 401, message = "ER006" }
  end

  -- Retrieve the secret
  local jwt_secret, retrieve_err = db.secret.get(config.jwt_secret, jwt_secret_key)

  if retrieve_err then
    return error(retrieve_err)
  end

  if not jwt_secret then
    -- return false, { status = 401, message = "No credentials found for given '" .. conf.key_claim_name .. "'" }
    return false, { status = 401, message = "ER007" }
  end

  local algorithm = jwt_secret.algorithm or "HS256"

  -- Verify "alg"
  if header.alg ~= algorithm then
    -- return false, { status = 401, message = "Invalid algorithm" }
    return false, { status = 401, message = "ER008" }
  end

  local jwt_secret_value = algorithm ~= nil and algorithm:sub(1, 2) == "HS" and
                           jwt_secret.secret or jwt_secret.rsa_public_key

  if conf.secret_is_base64 then
    jwt_secret_value = jwt.base64_decode(jwt_secret_value)
  end

  if not jwt_secret_value then
    -- return false, { status = 401, message = "Invalid key/secret" }
    return false, { status = 401, message = "ER009" }
  end

  -- Now verify the JWT signature
  if not jwt:verify_signature(jwt_secret_value) then
    -- return false, { status = 401, message = "Invalid signature" }
    return false, { status = 401, message = "ER010" }
  end

  -- Verify the JWT registered claims
  local ok_claims, errors = jwt:verify_registered_claims(conf.claims_to_verify)
  if not ok_claims then
    return false, { status = 401, errors = errors }
  end

  --- Check that the maximum allowed expiration is not reached
  if conf.maximum_expiration ~= nil and conf.maximum_expiration > 0 then
    local ok, expiration_err = jwt:check_maximum_expiration(conf.maximum_expiration)
    if not ok then
      return false, { status = 401, errors = expiration_err }
    end
  end

  -- Retrieve the consumer
  local consumer = jwt_secret.consumer

  -- However this should not happen
  if not consumer then
    return false, {
      status = 401,
      message = fmt("Could not find consumer for '%s=%s'", conf.key_claim_name, jwt_secret_key)
    }
  end

  -- set consumer
  local constants = db.constants.get()
  set_consumer(constants, consumer, jwt_secret, token)

  return true
end

function _M.access(config)
  local conf = config.conf

  if not conf.run_on_preflight and ngx.req.get_method() == "OPTIONS" then
    return
  end

  local ok, err = do_authentication(config)
  if not ok then
    ngx.status = err.status
    ngx.header.content_type = "application/json"

    return ngx.say(json.encode(err))
  end
end

return _M

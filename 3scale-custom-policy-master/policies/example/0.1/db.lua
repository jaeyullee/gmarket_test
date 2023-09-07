local ipairs = ipairs
local ngx = ngx

local constants = {
  HEADERS = {
    CONSUMER_ID = "X-Consumer-ID",
    CONSUMER_CUSTOM_ID = "X-Consumer-Custom-ID",
    CONSUMER_USERNAME = "X-Consumer-Username",
    CREDENTIAL_IDENTIFIER = "X-Credential-Identifier",
    CREDENTIAL_USERNAME = "X-Credential-Username",
    ANONYMOUS = "X-Anonymous-Consumer"
  }
}

local _M = {
  secret = {},
  consumer = {},
  constants = {},
  config = {}
}

function _M.constants.get()
  return constants
end

function _M.secret.get(jwt_secret, iss)
  ngx.log(ngx.INFO, iss)
  for _, v in ipairs(jwt_secret) do
    if v.key == iss then
      return v
    end
  end
end

return _M

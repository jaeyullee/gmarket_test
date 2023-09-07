local _M = {}
_M.__index = _M

local ngx = ngx
local type = type
local ipairs = ipairs
local re_gmatch = ngx.re.gmatch
local error = error

function _M.retrieve_token(conf)
  local args = ngx.req.get_uri_args()
  if conf.uri_param_names ~= nil and type(conf.uri_param_names) == "table" then
    for _, v in ipairs(conf.uri_param_names) do
      if args[v] then
        return args[v]
      end
    end
  end

  local var = ngx.var
  if conf.cookie_names ~= nil and type(conf.cookie_names) == "table" then
    for _, v in ipairs(conf.cookie_names) do
      local cookie = var["cookie_" .. v]
      if cookie and cookie ~= "" then
        return cookie
      end
    end
  end

  local request_headers = ngx.req.get_headers()
  if conf.header_names ~= nil and type(conf.header_names) == "table" then
    for _, v in ipairs(conf.header_names) do
      local token_header = request_headers[v]
      if token_header then
        if type(token_header) == "table" then
          token_header = token_header[1]
        end
        local iterator, iter_err = re_gmatch(token_header, "\\s*[Bb]earer\\s+(.+)")
        if not iterator then
          ngx.log(ngx.ERR, iter_err)
          break
        end

        local m, err = iterator()
        if err then
          ngx.log(ngx.ERR, err)
          break
        end

        if m and #m > 0 then
          return m[1]
        end
      end
    end
  end
end

function _M.set_consumer(constants, consumer, credential, token)
  local TABLE_OR_NIL = { ["table"] = true, ["nil"] = true }
  if not TABLE_OR_NIL[type(consumer)] then
    error("consumer must be a table or nil", 2)
  elseif not TABLE_OR_NIL[type(credential)] then
    error("credential must be a table or nil", 2)
  elseif credential == nil and consumer == nil then
    error("either credential or consumer must be provided", 2)
  end

  local ctx = ngx.ctx
  ctx.authenticated_consumer = consumer
  ctx.authenticated_credential = credential

  local set_header = ngx.req.set_header
  local clear_header = ngx.req.set_header

  if consumer and consumer.id then
    set_header(constants.HEADERS.CONSUMER_ID, consumer.id)
  else
    clear_header(constants.HEADERS.CONSUMER_ID)
  end

  if consumer and consumer.custom_id then
    set_header(constants.HEADERS.CONSUMER_CUSTOM_ID, consumer.custom_id)
  else
    clear_header(constants.HEADERS.CONSUMER_CUSTOM_ID)
  end

  if consumer and consumer.username then
    set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username)
  else
    clear_header(constants.HEADERS.CONSUMER_USERNAME)
  end

  if credential and credential.key then
    set_header(constants.HEADERS.CREDENTIAL_IDENTIFIER, credential.key)
  else
    clear_header(constants.HEADERS.CREDENTIAL_IDENTIFIER)
  end

  clear_header(constants.HEADERS.CREDENTIAL_USERNAME)

  if token then
    ngx.ctx.authenticated_jwt_token = token
  else
    ngx.ctx.authenticated_jwt_token = nil
  end
end

return _M

local handler = require "handler"
-- local json = require "cjson"

local _M = require('apicast.policy').new('Example', '0.1')
local new = _M.new


function _M.new(config)
  local self = new(config)
  self.config = config
  return self
end

function _M:access()
  -- ngx.say(json.encode(self.config))
  handler.access(self.config)
end

return _M

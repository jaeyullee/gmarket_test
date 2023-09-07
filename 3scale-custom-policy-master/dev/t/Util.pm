package t::Util;

use strict;
use warnings;

our $HttpConfig = <<_EOC_;
    lua_package_path \'/etc/nginx/conf.d/scripts/?.lua;;\';
    init_by_lua_block {
        local outfile = "$Test::Nginx::Util::ErrLogFile"
        local dump = require "jit.dump"
        dump.on(nil, outfile)
    }
_EOC_

1;

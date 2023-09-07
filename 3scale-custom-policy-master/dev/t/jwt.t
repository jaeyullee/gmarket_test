use Test::Nginx::Socket 'no_plan';
use t::Util;

run_tests();

__DATA__

=== TEST: Token Based Authentication
--- http_config eval: $t::Util::HttpConfig
--- config
location = /t {
    default_type 'application/json';
    content_by_lua_block {
        local handler = require "handler"
        local config = {
            conf = {
                header_names = {"Authorization"},
                key_claim_name = "iss",
                secret_is_base64 = true,
                run_on_preflight = false,
                maximum_expiration = 3600
            },
            jwt_secret = {
                {
                    key = "service A",
                    algorithm = "HS256",
                    secret = "secret",
                    consumer = {
                        id = "68aca0ee-ca34-4fe8-8bb4-3657eaf7508c",
                        custom_id = "custom_id_1",
                        username ="David"
                    }
                }
            }
        }
        handler.access(config)
    }
}
--- request
GET /t
--- more_headers
Authorization: Bearer badtoken
--- response_body
{"status":401,"message":"Bad token; invalid JSON"}
--- error_code: 401

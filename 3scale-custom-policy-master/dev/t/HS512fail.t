use Test::Nginx::Socket 'no_plan';
use t::Util;

run_tests();

__DATA__

=== TEST: Token Based Authentication fail (alg: HS512, base64 encoded secret)
--- http_config eval: $t::Util::HttpConfig
--- config
location = /t1 {
    default_type 'application/json';
    content_by_lua_block {
        local handler = require "handler"
        local jwt_parser = require "jwt_parser"
        local alg = "HS512"
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
                    algorithm = alg,
                    secret = jwt_parser.base64_encode("secret"),
                    consumer = {
                        id = "68aca0ee-ca34-4fe8-8bb4-3657eaf7508c",
                        custom_id = "custom_id_1",
                        username ="David"
                    }
                }
            }
        }
        local token = jwt_parser.encode_token({ iss = "service A", sub = "1234", exp = ngx.time() + 3600 }, "secretfail", { alg = alg, typ = "JWT" })
        ngx.req.set_header("Authorization", "Bearer " .. token)
        handler.access(config)
    }
}
--- request
GET /t1
--- response_body
{"status":401,"message":"Invalid signature"}
--- error_code: 401

=== TEST: Token Based Authentication fail (alg: HS512, non-base64 encoded secret)
--- http_config eval: $t::Util::HttpConfig
--- config
location = /t2 {
    default_type 'application/json';
    content_by_lua_block {
        local handler = require "handler"
        local jwt_parser = require "jwt_parser"
        local alg = "HS512"
        local config = {
            conf = {
                header_names = {"Authorization"},
                key_claim_name = "iss",
                secret_is_base64 = false,
                run_on_preflight = false,
                maximum_expiration = 3600
            },
            jwt_secret = {
                {
                    key = "service A",
                    algorithm = alg,
                    secret = "secret",
                    consumer = {
                        id = "68aca0ee-ca34-4fe8-8bb4-3657eaf7508c",
                        custom_id = "custom_id_1",
                        username ="David"
                    }
                }
            }
        }
        local token = jwt_parser.encode_token({ iss = "service A", sub = "1234", exp = ngx.time() + 3600 }, "secretfail", { alg = alg, typ = "JWT" })
        ngx.req.set_header("Authorization", "Bearer " .. token)
        handler.access(config)
    }
}
--- request
GET /t2
--- response_body
{"status":401,"message":"Invalid signature"}
--- error_code: 401

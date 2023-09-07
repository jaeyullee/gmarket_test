use Test::Nginx::Socket 'no_plan';
use t::Util;

run_tests();

__DATA__

=== TEST: Token Based Authentication fail (alg: ES256, base64 encoded secret)
--- http_config eval: $t::Util::HttpConfig
--- config
location = /t1 {
    default_type 'application/json';
    content_by_lua_block {
        local handler = require "handler"
        local jwt_parser = require "jwt_parser"
        local alg = "ES256"

local es256_private_key = [[
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgD8enltAi05AIoF2A
fqwctkCFME0gP/HwVvnHCtatlVChRANCAAQDBOV5Pwz+uUXycT+qFj7bprEnMWuh
XPtZyIZljEHXAj9TSMmDKvk8F1ABIXLAb5CAY//EPd4SjNSdU5f7XP72
-----END PRIVATE KEY-----
]]
local es256_public_key = [[
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEAwTleT8M/rlF8nE/qhY+26axJzFr
oVz7WciGZYxB1wI/U0jJgyr5PBdQASFywG+QgGP/xD3eEozUnVOX+1z+9g==
-----END PUBLIC KEY-----
]]
local rs256_public_key = [[
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAw5mp3MS3hVLkHwB9lMrE
x34MjYCmKeH/XeMLexNpTd1FzuNv6rArovTY763CDo1Tp0xHz0LPlDJJtpqAgsnf
DwCcgn6ddZTo1u7XYzgEDfS8J4SYdcKxZiSdVTpb9k7pByXfnwK/fwq5oeBAJXIS
v5ZLB1IEVZHhUvGCH0udlJ2vadquR03phBHcvlNmMbJGWAetkdcKyi+7TaW7OUSj
lge4WYERgYzBB6eJH+UfPjmw3aSPZcNXt2RckPXEbNrL8TVXYdEvwLJoJv9/I8JP
FLiGOm5uTMEk8S4txs2efueg1XyymilCKzzuXlJvrvPA4u6HI7qNvuvkvUjQmwBH
gwIDAQAB
-----END PUBLIC KEY-----
]]

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
                    rsa_public_key = jwt_parser.base64_encode(rs256_public_key:gsub('1z+', 'zzz')),
                    consumer = {
                        id = "68aca0ee-ca34-4fe8-8bb4-3657eaf7508c",
                        custom_id = "custom_id_1",
                        username ="David"
                    }
                }
            }
        }
        local token = jwt_parser.encode_token({ iss = "service A", sub = "1234", exp = ngx.time() + 3600 }, es256_private_key, { alg = alg, typ = "JWT" })
        ngx.req.set_header("Authorization", "Bearer " .. token)
        handler.access(config)
    }
}
--- request
GET /t1
--- response_body
{"status":401,"message":"Invalid signature"}
--- error_code: 401

=== TEST: Token Based Authentication fail (alg: ES256, non-base64 encoded secret)
--- http_config eval: $t::Util::HttpConfig
--- config
location = /t2 {
    default_type 'application/json';
    content_by_lua_block {
        local handler = require "handler"
        local jwt_parser = require "jwt_parser"
        local alg = "ES256"

local es256_private_key = [[
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgD8enltAi05AIoF2A
fqwctkCFME0gP/HwVvnHCtatlVChRANCAAQDBOV5Pwz+uUXycT+qFj7bprEnMWuh
XPtZyIZljEHXAj9TSMmDKvk8F1ABIXLAb5CAY//EPd4SjNSdU5f7XP72
-----END PRIVATE KEY-----
]]
local es256_public_key = [[
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEAwTleT8M/rlF8nE/qhY+26axJzFr
oVz7WciGZYxB1wI/U0jJgyr5PBdQASFywG+QgGP/xD3eEozUnVOX+1z+9g==
-----END PUBLIC KEY-----
]]
local rs256_public_key = [[
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAw5mp3MS3hVLkHwB9lMrE
x34MjYCmKeH/XeMLexNpTd1FzuNv6rArovTY763CDo1Tp0xHz0LPlDJJtpqAgsnf
DwCcgn6ddZTo1u7XYzgEDfS8J4SYdcKxZiSdVTpb9k7pByXfnwK/fwq5oeBAJXIS
v5ZLB1IEVZHhUvGCH0udlJ2vadquR03phBHcvlNmMbJGWAetkdcKyi+7TaW7OUSj
lge4WYERgYzBB6eJH+UfPjmw3aSPZcNXt2RckPXEbNrL8TVXYdEvwLJoJv9/I8JP
FLiGOm5uTMEk8S4txs2efueg1XyymilCKzzuXlJvrvPA4u6HI7qNvuvkvUjQmwBH
gwIDAQAB
-----END PUBLIC KEY-----
]]

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
                    rsa_public_key = rs256_public_key:gsub('1z+', 'zzz'),
                    consumer = {
                        id = "68aca0ee-ca34-4fe8-8bb4-3657eaf7508c",
                        custom_id = "custom_id_1",
                        username ="David"
                    }
                }
            }
        }
        local token = jwt_parser.encode_token({ iss = "service A", sub = "1234", exp = ngx.time() + 3600 }, es256_private_key, { alg = alg, typ = "JWT" })
        ngx.req.set_header("Authorization", "Bearer " .. token)
        handler.access(config)
    }
}
--- request
GET /t2
--- response_body
{"status":401,"message":"Invalid signature"}
--- error_code: 401

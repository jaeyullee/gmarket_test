use Test::Nginx::Socket 'no_plan';
use t::Util;

run_tests();

__DATA__

=== TEST: Token Based Authentication (alg: RS512, base64 encoded secret)
--- http_config eval: $t::Util::HttpConfig
--- config
location = /t1 {
    default_type 'application/json';
    content_by_lua_block {
        local handler = require "handler"
        local jwt_parser = require "jwt_parser"
        local alg = "RS512"

local rs512_private_key = [[
-----BEGIN RSA PRIVATE KEY-----
MIIEoQIBAAKCAQBoyqH30IH7YnHk2YLLygDwD0LUvrXRcWwVCsN1/2+DB+FLV8f+
/VoLegUowlcCea6vJCu9q9vnJqz2UhK7eN/kDYNhnx4WIdc3KjL+SXnp3KZozgn/
uCUeEYnMNRXLlx7GefG+C1yUgcFAaVJoyxx7dQellqWYrTW3nW9fMhioxSvuJUU8
u5v31GPzNeF69bfeKdI1NzhVLkztJhogEXdIgYitEcqepJQe1FpSBbVjdT5xbuMN
80pSnJHR11Qw2dPp6lDlao/hnvkYW77CZOVgK02oB0UEqjaasxPcaHiWerSP0yb7
nCdjR0kTgKA8um/gk0/F+FO3aOkrsZsgpK2vAgMBAAECggEAZVybjrmBAUgYIuTC
P50Fiy831dEizZSIl1Hx/xE1K+lTYy1lpqApmTBODT7uKtbIwWCbbrvt2YjvhNOe
ivhAmLb5flQLJh1Vr2aCLLWl1zA3RukFgvT78jnEsGIo0uU6P4F08/7JblyUMVmu
/O56fnCVFPbC9wuUCieestYiRBw3Z7TwcRmUx5JWJUuj4gzuFfRSyuzYeJoYUSJF
OLu5XtXaW4k0nj/LILC89qxQT/8HIIYa/7+S8TdbBfws6kQt5yiwUUOirzjOeuY9
RIvbmgapAVZhI2oxofu1r2XNLBBPHFDHlLeJasqRAa7vk3yVYtrcg20c5q3MZ1tx
Q+7NAQKBgQCqUxzBxK0h6d0GKe0rt30NSfNhFiKPR2AkQ8hXsjrCfJ36PbQqRyEt
zw13hgaHoS4yfj+19aQem1ZoTZVsUTvkD8CBBHZ/1PYjPoeOrjt6mDfp402z+f3E
FZTQq0dNFGsSGHn1yRUqXebM3SbbyDIDUqnHXMC1Dzsm2vSu6EJSIwKBgQCdgMAM
bQge8cQSevcARctOjqVpwirfsfqLebP+SBmzyNrs9Z5u8l/0EooojMRaGVClNzvb
yYCW6DWzac0jCKRuD9Svd41gGC3R5PztGGOyvLLkk33ad9NChwCz9np66THmQn6n
B+K/XrjDwUVHnItcRiARyXP3vn3uryv1hvRRBQKBgB7MtreHZDNswc4aiMvN+2wK
wlr9ELTOGGGWbEUHcr62oC6fN9QpVqOc/HdvogCmsd7pm4XA7LOoLWDhHrMeoXDl
NE9gSjllfjjzVroDYbgSjJHby7JO84egy29MebFDjvUPvgYnHY+yuUi0eRFnSzv0
l8T4TdSv82dcUsDKOSv3AoGAQmlxkUvAKtwiovA6imDjkyJO2UNINL6lOH5+yO+5
9rbwqQ4AWiPVFeNjYinI+XzHJoMduFVE5VzQl/A60VTpkIcYVUyBzk0jtOdrRsYL
8+fhPsR6Qs5XxCuMvlVl28HMipzrLp8Cm1LjcZdjEQkPMj9XcmiRf5tRGn2+eW8I
QckCgYAYYzr4nHmarWduk/1Fgm2qmFE96U/TjIRmk9vspwk5y47oM7LrnzU2Iyio
vaL3rwMZ0AcBcEOUvANkMCDAxgJZljeDr4IzUMQs95+m7Wb6BQTs4vKSLPGWYdjd
y1FoR04hSreMjG+K+mtQLGJC4USI1AJx1wKihgoxGrI1/7YiwQ==
-----END RSA PRIVATE KEY-----
]]
local rs512_public_key = [[
-----BEGIN PUBLIC KEY-----
MIIBITANBgkqhkiG9w0BAQEFAAOCAQ4AMIIBCQKCAQBoyqH30IH7YnHk2YLLygDw
D0LUvrXRcWwVCsN1/2+DB+FLV8f+/VoLegUowlcCea6vJCu9q9vnJqz2UhK7eN/k
DYNhnx4WIdc3KjL+SXnp3KZozgn/uCUeEYnMNRXLlx7GefG+C1yUgcFAaVJoyxx7
dQellqWYrTW3nW9fMhioxSvuJUU8u5v31GPzNeF69bfeKdI1NzhVLkztJhogEXdI
gYitEcqepJQe1FpSBbVjdT5xbuMN80pSnJHR11Qw2dPp6lDlao/hnvkYW77CZOVg
K02oB0UEqjaasxPcaHiWerSP0yb7nCdjR0kTgKA8um/gk0/F+FO3aOkrsZsgpK2v
AgMBAAE=
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
                    rsa_public_key = jwt_parser.base64_encode(rs512_public_key),
                    consumer = {
                        id = "68aca0ee-ca34-4fe8-8bb4-3657eaf7508c",
                        custom_id = "custom_id_1",
                        username ="David"
                    }
                }
            }
        }
        local token = jwt_parser.encode_token({ iss = "service A", sub = "1234", exp = ngx.time() + 3600 }, rs512_private_key, { alg = alg, typ = "JWT" })
        ngx.req.set_header("Authorization", "Bearer " .. token)
        handler.access(config)
    }
}
--- request
GET /t1
--- error_code: 200

=== TEST: Token Based Authentication (alg: RS512, non-base64 encoded secret)
--- http_config eval: $t::Util::HttpConfig
--- config
location = /t2 {
    default_type 'application/json';
    content_by_lua_block {
        local handler = require "handler"
        local jwt_parser = require "jwt_parser"
        local alg = "RS512"

local rs512_private_key = [[
-----BEGIN RSA PRIVATE KEY-----
MIIEoQIBAAKCAQBoyqH30IH7YnHk2YLLygDwD0LUvrXRcWwVCsN1/2+DB+FLV8f+
/VoLegUowlcCea6vJCu9q9vnJqz2UhK7eN/kDYNhnx4WIdc3KjL+SXnp3KZozgn/
uCUeEYnMNRXLlx7GefG+C1yUgcFAaVJoyxx7dQellqWYrTW3nW9fMhioxSvuJUU8
u5v31GPzNeF69bfeKdI1NzhVLkztJhogEXdIgYitEcqepJQe1FpSBbVjdT5xbuMN
80pSnJHR11Qw2dPp6lDlao/hnvkYW77CZOVgK02oB0UEqjaasxPcaHiWerSP0yb7
nCdjR0kTgKA8um/gk0/F+FO3aOkrsZsgpK2vAgMBAAECggEAZVybjrmBAUgYIuTC
P50Fiy831dEizZSIl1Hx/xE1K+lTYy1lpqApmTBODT7uKtbIwWCbbrvt2YjvhNOe
ivhAmLb5flQLJh1Vr2aCLLWl1zA3RukFgvT78jnEsGIo0uU6P4F08/7JblyUMVmu
/O56fnCVFPbC9wuUCieestYiRBw3Z7TwcRmUx5JWJUuj4gzuFfRSyuzYeJoYUSJF
OLu5XtXaW4k0nj/LILC89qxQT/8HIIYa/7+S8TdbBfws6kQt5yiwUUOirzjOeuY9
RIvbmgapAVZhI2oxofu1r2XNLBBPHFDHlLeJasqRAa7vk3yVYtrcg20c5q3MZ1tx
Q+7NAQKBgQCqUxzBxK0h6d0GKe0rt30NSfNhFiKPR2AkQ8hXsjrCfJ36PbQqRyEt
zw13hgaHoS4yfj+19aQem1ZoTZVsUTvkD8CBBHZ/1PYjPoeOrjt6mDfp402z+f3E
FZTQq0dNFGsSGHn1yRUqXebM3SbbyDIDUqnHXMC1Dzsm2vSu6EJSIwKBgQCdgMAM
bQge8cQSevcARctOjqVpwirfsfqLebP+SBmzyNrs9Z5u8l/0EooojMRaGVClNzvb
yYCW6DWzac0jCKRuD9Svd41gGC3R5PztGGOyvLLkk33ad9NChwCz9np66THmQn6n
B+K/XrjDwUVHnItcRiARyXP3vn3uryv1hvRRBQKBgB7MtreHZDNswc4aiMvN+2wK
wlr9ELTOGGGWbEUHcr62oC6fN9QpVqOc/HdvogCmsd7pm4XA7LOoLWDhHrMeoXDl
NE9gSjllfjjzVroDYbgSjJHby7JO84egy29MebFDjvUPvgYnHY+yuUi0eRFnSzv0
l8T4TdSv82dcUsDKOSv3AoGAQmlxkUvAKtwiovA6imDjkyJO2UNINL6lOH5+yO+5
9rbwqQ4AWiPVFeNjYinI+XzHJoMduFVE5VzQl/A60VTpkIcYVUyBzk0jtOdrRsYL
8+fhPsR6Qs5XxCuMvlVl28HMipzrLp8Cm1LjcZdjEQkPMj9XcmiRf5tRGn2+eW8I
QckCgYAYYzr4nHmarWduk/1Fgm2qmFE96U/TjIRmk9vspwk5y47oM7LrnzU2Iyio
vaL3rwMZ0AcBcEOUvANkMCDAxgJZljeDr4IzUMQs95+m7Wb6BQTs4vKSLPGWYdjd
y1FoR04hSreMjG+K+mtQLGJC4USI1AJx1wKihgoxGrI1/7YiwQ==
-----END RSA PRIVATE KEY-----
]]
local rs512_public_key = [[
-----BEGIN PUBLIC KEY-----
MIIBITANBgkqhkiG9w0BAQEFAAOCAQ4AMIIBCQKCAQBoyqH30IH7YnHk2YLLygDw
D0LUvrXRcWwVCsN1/2+DB+FLV8f+/VoLegUowlcCea6vJCu9q9vnJqz2UhK7eN/k
DYNhnx4WIdc3KjL+SXnp3KZozgn/uCUeEYnMNRXLlx7GefG+C1yUgcFAaVJoyxx7
dQellqWYrTW3nW9fMhioxSvuJUU8u5v31GPzNeF69bfeKdI1NzhVLkztJhogEXdI
gYitEcqepJQe1FpSBbVjdT5xbuMN80pSnJHR11Qw2dPp6lDlao/hnvkYW77CZOVg
K02oB0UEqjaasxPcaHiWerSP0yb7nCdjR0kTgKA8um/gk0/F+FO3aOkrsZsgpK2v
AgMBAAE=
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
                    rsa_public_key = rs512_public_key,
                    consumer = {
                        id = "68aca0ee-ca34-4fe8-8bb4-3657eaf7508c",
                        custom_id = "custom_id_1",
                        username ="David"
                    }
                }
            }
        }
        local token = jwt_parser.encode_token({ iss = "service A", sub = "1234", exp = ngx.time() + 3600 }, rs512_private_key, { alg = alg, typ = "JWT" })
        ngx.req.set_header("Authorization", "Bearer " .. token)
        handler.access(config)
    }
}
--- request
GET /t2
--- error_code: 200

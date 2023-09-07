local openssl_digest = require "custom.openssl.digest"
local openssl_hmac = require "custom.openssl.hmac"
local openssl_pkey = require "custom.openssl.pkey"

local asn_sequence = require "asn_sequence"

local sub = string.sub
local assert = assert

local _M = {}
_M.__index = _M

--- Supported algorithms for signing tokens.
local alg_sign = {
  HS256 = function(data, key) return openssl_hmac.new(key, "sha256"):final(data) end,
  HS384 = function(data, key) return openssl_hmac.new(key, "sha384"):final(data) end,
  HS512 = function(data, key) return openssl_hmac.new(key, "sha512"):final(data) end,
  RS256 = function(data, key)
    local digest = openssl_digest.new("sha256")
    assert(digest:update(data))

    return assert(openssl_pkey.new(key):sign(digest))
  end,
  RS512 = function(data, key)
    local digest = openssl_digest.new("sha512")
    assert(digest:update(data))

    return assert(openssl_pkey.new(key):sign(digest))
  end,
  ES256 = function(data, key)
    local pkey = openssl_pkey.new(key)
    local digest = openssl_digest.new("sha256")
    assert(digest:update(data))
    local signature = assert(pkey:sign(digest))

    local derSequence = asn_sequence.parse_simple_sequence(signature)
    local r = asn_sequence.unsign_integer(derSequence[1], 32)
    local s = asn_sequence.unsign_integer(derSequence[2], 32)
    assert(#r == 32)
    assert(#s == 32)

    return r .. s
  end
}


--- Supported algorithms for verifying tokens.
local alg_verify = {
  HS256 = function(data, signature, key) return signature == alg_sign.HS256(data, key) end,
  HS384 = function(data, signature, key) return signature == alg_sign.HS384(data, key) end,
  HS512 = function(data, signature, key) return signature == alg_sign.HS512(data, key) end,
  RS256 = function(data, signature, key)
    local pkey, _ = openssl_pkey.new(key)
    assert(pkey, "Consumer Public Key is Invalid")
    local digest = openssl_digest.new("sha256")
    assert(digest:update(data))

    return pkey:verify(signature, digest)
  end,
  RS512 = function(data, signature, key)
    local pkey, _ = openssl_pkey.new(key)
    assert(pkey, "Consumer Public Key is Invalid")
    local digest = openssl_digest.new("sha512")
    assert(digest:update(data))

    return pkey:verify(signature, digest)
  end,
  ES256 = function(data, signature, key)
    local pkey, _ = openssl_pkey.new(key)
    assert(pkey, "Consumer Public Key is Invalid")
    assert(#signature == 64, "Signature must be 64 bytes.")
    local asn = {}
    asn[1] = asn_sequence.resign_integer(sub(signature, 1, 32))
    asn[2] = asn_sequence.resign_integer(sub(signature, 33, 64))
    local signatureAsn = asn_sequence.create_simple_sequence(asn)
    local digest = openssl_digest.new("sha256")
    assert(digest:update(data))

    return pkey:verify(signatureAsn, digest)
  end
}

_M.alg_sign = alg_sign
_M.alg_verify = alg_verify

return _M

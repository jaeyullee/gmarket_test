local ffi = require "ffi"

require "custom.openssl.include.ossl_typ"
require "custom.openssl.include.x509v3"
require "custom.openssl.include.x509"
local asn1_macro = require "custom.openssl.include.asn1"

asn1_macro.declare_asn1_functions("X509_EXTENSION")

ffi.cdef [[
  struct v3_ext_ctx {
      int flags;
      X509 *issuer_cert;
      X509 *subject_cert;
      X509_REQ *subject_req;
      X509_CRL *crl;
      /*X509V3_CONF_METHOD*/ void *db_meth;
      void *db;
  };
]]
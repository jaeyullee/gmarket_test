# 3scale-custom-policy
# custom-policy-for-jwt-authentication

custom-policy-for-jwt-authentication

```bash
# minishift test
minishift start --memory 8GB --cpus 4
oc new-app \
  --param WILDCARD_DOMAIN="$(minishift ip).nip.io" \
  --param AMP_RELEASE=2.8.0 \
  -f https://raw.githubusercontent.com/3scale/3scale-operator/2.6-stable/pkg/3scale/amp/auto-generated-templates/amp/amp-eval.yml

# custom policy
oc new-app \
  --param AMP_RELEASE=2.8.0 \
  -f minishift.yml
oc start-build apicast-example-policy
oc start-build apicast-custom-policies

# custom policy
oc new-app \
  --param AMP_RELEASE=2.8 \
  -f openshift.yml
oc start-build apicast-example-policy
oc start-build apicast-custom-policies
```

## run tests

```bash
prove -I. -r t
```

## 배포에 포함되어야 하는 파일 목록
```
|____Roverfile
|____openshift.yml
|____cpanfile
|____.luacheckrc
|____.s2i
| |____bin
| | |____assemble
| | |____run
|____spec
|____policies
| |____example
| | |____0.1
| | | |____cjson
| | | | |____util.lua
| | | |____apicast-policy.json
| | | |____init.lua
| | | |____handler.lua
| | | |____asn_sequence.lua
| | | |____jwt_parser.lua
| | | |____alg.lua
| | | |____db.lua
| | | |____util.lua
| | | |____custom
| | | | |____openssl.lua
| | | | |____openssl
| | | | | |____pkey.lua
| | | | | |____asn1.lua
| | | | | |____rsa.lua
| | | | | |____bn.lua
| | | | | |____rand.lua
| | | | | |____hmac.lua
| | | | | |____include
| | | | | | |____asn1.lua
| | | | | | |____crypto.lua
| | | | | | |____pem.lua
| | | | | | |____rsa.lua
| | | | | | |____bn.lua
| | | | | | |____rand.lua
| | | | | | |____evp.lua
| | | | | | |____hmac.lua
| | | | | | |____ossl_typ.lua
| | | | | | |____x509_vfy.lua
| | | | | | |____x509
| | | | | | | |____init.lua
| | | | | | | |____crl.lua
| | | | | | | |____altname.lua
| | | | | | | |____extension.lua
| | | | | | | |____csr.lua
| | | | | | | |____name.lua
| | | | | | |____x509v3.lua
| | | | | | |____objects.lua
| | | | | | |____stack.lua
| | | | | | |____ec.lua
| | | | | | |____bio.lua
| | | | | | |____kdf.lua
| | | | | |____cipher.lua
| | | | | |____x509
| | | | | | |____init.lua
| | | | | | |____extension
| | | | | | | |____dist_points.lua
| | | | | | | |____info_access.lua
| | | | | | |____crl.lua
| | | | | | |____store.lua
| | | | | | |____altname.lua
| | | | | | |____chain.lua
| | | | | | |____extension.lua
| | | | | | |____csr.lua
| | | | | | |____name.lua
| | | | | | |____extensions.lua
| | | | | |____ecx.lua
| | | | | |____version.lua
| | | | | |____objects.lua
| | | | | |____stack.lua
| | | | | |____ec.lua
| | | | | |____aux
| | | | | | |____jwk.lua
| | | | | | |____ctypes.lua
| | | | | |____kdf.lua
| | | | | |____util.lua
| | | | | |____err.lua
| | | | | |____digest.lua
| | | |____example.lua
|____.editorconfig
|____README.md
|____.gitignore
|____dev
| |____Dockerfile
| |____t
| | |____ES256.t
| | |____ES256fail.t
| | |____HS256fail.t
| | |____jwt.t
| | |____Util.pm
| | |____RS512fail.t
| | |____HS512.t
| | |____HS384fail.t
| | |____HS384.t
| | |____RS256fail.t
| | |____HS256.t
| | |____RS512.t
| | |____HS512fail.t
| | |____RS256.t
| |____docker-compose.yml
| |____conf.d
| | |____example.conf
|____Roverfile.lock
```
## Error Responses

### 전달된 토큰을 찾을 수 없는 경우 (in http headers, query parameters or cookies)

```json
// {"status":401,"message":"Unauthorized"}
{"status":401,"message":"ER001"}
```

### 전달된 토큰이 여러개인 경우

```json
// {"status":401,"message":"Multiple tokens provided"}
{"status":401,"message":"ER002"}
```

### 정상적으로 확인할 수 없는 토큰인 경우

```json
// {"status":401,"message":"Unrecognizable token"}
{"status":401,"message":"ER003"}
```

### claims data type이 맞지 않는 경우

```json
// {
//     "status":401,
//     "errors": {
//         "exp": "must be a number",
//         "nbf": "must be a number"
//     }
// }
{
    "status":401,
    "errors": {
        "exp": "ER004",
        "nbf": "ER004"
    }
}
```

### json web token이 헤더.클레임.시그니처 형식이 아니거나, 각 부분이 base64로 encoding되어 있지 않은 경우

```json
// {"status":401,"message":"Bad token; invalid JSON"}
{"status":401,"message":"ER014"}
```

### json web token의 헤더.클레임.시그니처에서 헤더 부분에 alg 값이 지정되어 있지 않거나, 헤더에 지정되어있는 alg가 지원되는 알고리즘이 아닐 경우

```json
// {"status":401,"message":"Bad token; invalid alg"}
{"status":401,"message":"ER015"}
```

### json web token의 헤더.클레임.시그니처에서 클레임 부분을 base64 decode를 수행했을 때, 내부 값이 비어있는 경우

```json
// {"status":401,"message":"Bad token; invalid claims"}
{"status":401,"message":"ER016"}
```

### json web token의 헤더.클레임.시그니처에서 시그니처 부분을 base64 decode를 수행했을 때, 내부 값이 비어있는 경우

```json
// {"status":401,"message":"Bad token; invalid signature"}
{"status":401,"message":"ER017"}
```

### json web token의 헤더.클레임.시그니처에서 헤더나 클레임에 key claim name이 없는 경우

```json
// {"status":401,"message":"No mandatory '설정한 key claim name' in claims"}
{"status":401,"message":"ER005"}
```

### json web token의 헤더.클레임.시그니처에서 헤더나 클레임에 key claim name에 공백 값("")이 입력되어 있는 경우

```json
// {"status":401,"message":"Invalid '설정한 key claim name' in claims"}
{"status":401,"message":"ER006"}
```

### json web token 헤더.클레임.시그니처에서 클레임 또는 헤더에 포함되어 있는 key claim name(예: iss)에 입력된 키 값으로 credential을 찾을 수 없는 경우

```json
// {"status":401,"message":"No credentials found for given '설정한 key claim name'"}
{"status":401,"message":"ER007"}
```

### json web token 헤더.클레임.시그니처에서 클레임 또는 헤더에 포함되어 있는 key claim name(예: iss)에 입력된 키 값으로 찾은 credential의 algorithm과 실제 토큰 헤더에 지정된 alg가 다른 경우

```json
// {"status":401,"message":"Invalid algorithm"}
{"status":401,"message":"ER008"}
```

### json web token 헤더.클레임.시그니처에서 클레임 또는 헤더에 포함되어 있는 key claim name(예: iss)에 입력된 값으로 찾은 credential에 저장된 secret 또는 rsa public key가 없는 경우

```json
// {"status":401,"message":"Invalid key/secret"}
{"status":401,"message":"ER009"}
```

### json web token 헤더.클레임.시그니처에서 클레임 또는 헤더에 포함되어 있는 key claim name(예: iss)에 입력된 값으로 찾은 credential에 저장된 secret 또는 rsa public key로 실제 토큰 verify에 실패한 경우

```json
// {"status":401,"message":"Invalid signature"}
{"status":401,"message":"ER010"}
```

### 설정된 maximum expiration이 있을 때, (0보다 큰 값) json web token 헤더.클레임.시그니처에서 클레임 내에 exp 값 - 현재시간이 maximum expiration 보다 큰 경우

```json
// {"status":401,"errors":{"exp":"exceeds maximum allowed expiration"}}
{"status":401,"errors":{"exp":"ER011"}}
```

### nbf 혹은 exp 관련 에러 응답

```json
// {
//     "status":401,
//     "errors": {
//         "exp": "token expired", // 현재 시간보다 exp가 과거인 경우
//         "nbf": "token not valid yet", // 현재 시간보다 nbf가 미래인 경우
//     }
// }
{
    "status":401,
    "errors": {
        "exp": "ER013", // 현재 시간보다 exp가 과거인 경우
        "nbf": "ER012", // 현재 시간보다 nbf가 미래인 경우
    }
}
```

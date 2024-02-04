### 3scale Operator 2.13버전 설치를 위한 인덱스 이미지 준비
* cli 준비 (openshift-client, opm, grpcurl)
  https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/<ocp-버전>/openshift-client-linux-<ocp-버전>.tar.gz
  https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/<ocp-버전>/opm-linux-<ocp-version>.tar.gz
  https://github.com/fullstorydev/grpcurl/releases/download/v1.8.0/grpcurl_1.8.0_linux_x86_64.tar.gz
  
> 현재 배포 된 openshift version에 맞는 cli를 준비합니다.
> 이미 설치된 cli는 해당 단계를 건너뜁니다.

<br/>

* Operator 프루닝(OCP 4.10 까지는 sqlite 기반 방식으로 수행)
  참조 : https://docs.openshift.com/container-platform/4.10/operators/admin/olm-restricted-networks.html#olm-pruning-index-image_olm-restricted-networks
```
# tar -xvf openshift-client-linux-<ocp-버전>.tar.gz -C /usr/local/bin
# tar -xvf opm-linux-<ocp-버전>.tar.gz -C /usr/local/bin
# tar -zxvf grpcurl_1.8.0_linux_x86_64.tar.gz -C /usr/local/bin
```

> 이미 설치된 cli는 해당 단계를 건너뜁니다.

```
# podman login registry.redhat.io
# podman login <미러-레지스트리>:<port>
# podman run -p50051:50051 \
    -it registry.redhat.io/redhat/redhat-operator-index:v4.10
# podman ps

# grpcurl -plaintext localhost:50051 api.Registry/ListPackages > packages.out

# opm index prune -f registry.redhat.io/redhat/redhat-operator-index:v4.10 \
  -p 3scale-operator,apicast-operator \
  -t <미러-레지스트리>:<port>/<namespace>/redhat-operator-index-update:v4.10
# podman push <미러-레지스트리>:<port>/<namespace>/redhat-operator-index-update:v4.10
```

* Operator Catalog Mirror 생성
```
# oc adm catalog mirror <미러-레지스트리>:<port>/<namespace>/redhat-operator-index-update:v4.10 <미러-레지스트리>:<port> -a /<pull-secret-path>/pull-secret.json --filter-by-os="linux/amd64"
# ls manifests-redhat-operator-index-*
# mv manifests-redhat-operator-index-XXXX manifests-redhat-operator-index-v4-10

# ls ./manifests-redhat-operator-index-v4-10
# oc apply -f ./manifests-redhat-operator-index-v4-10
# oc get catalogsource -n openshift-marketplace
# oc get imagecontentsourcepolicy
```

> 외부에서 오퍼레이터 이미지 데이터 및 카탈로그를 반입하는 경우 manifests-redhat-operator-index-v4-10/* 의 파일들의 수정이 필요합니다.









# 주의 사항

Operator Mirror를 생성하는 과정에서 package명을 기존과 동일하게 해야만 해당 작업이 유효합니다.

catalogsource 명이 image명을 참조하여 생성되기 때문에, image 명의 첫 철자는 소문자 영어로 합니다.

3scale Operator의 APIManager에 apicast image를 지정 할 경우, ImageStream의 참조 이미지가 자동으로 변경됩니다. 이로 인해 BuildConfig의 trigger가 작동하여 Build가 수행됩니다. 이로 인한 ImageStream의 tag 참조값이 변경됨을 주의합니다.

3scale Operator의 APIManager에 apicast image는 Digest 형태의 이름으로만 참조가 가능합니다.



# 작업 과정



준비물

opm cli 다운로드 (https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.12/)



oc adm catalog mirror 명령으로 catalog.json 파일 추출

해당 방법은 mirror 대상 오퍼레이터 인덱스가 redhat-operator-index:v4.11 이상 버전인 경우에만 유효

v4.10 버전에서 해당 방법을 사용하고 싶은 경우 Creating a file-based catalog image( https://docs.openshift.com/container-platform/4.10/operators/admin/olm-managing-custom-catalogs.html#olm-creating-fb-catalog-image_olm-managing-custom-catalogs ) 의 1,2 절차 수행 이후 생성된 index.yaml 파일을 직접 수정해야 함

# oc adm catalog mirror \
   registry.redhat.io/redhat/redhat-operator-index:v4.12 \
   registry.test.cluster/olm \
   -a /root/pull-secret.json \
   --insecure \
   --index-filter-by-os="linux/amd64" \
   --manifests-only

끝까지 기다리지 말고, wrote declarative configs to /tmp/xxxxxx 로그가 보이면 ctrl-C 눌러서 중단하고 /tmp/xxxxxx/3scale-operator/catalog.json 폴더 확인



미러 생성 스크립트 작성

# vi threescale-2.14-operator-mirror.sh

#!/bin/bash
OPERATOR=3scale-operator
defaultChannel=threescale-2.14
ENTRY=3scale-operator.v0.11.11
SKIPRANGE=">=0.10.0 <0.11.11"
BUNDLE=registry.redhat.io/3scale-amp2/3scale-rhel7-operator-metadata@sha256:d8e94620237da97e1b65dac4fb616d21d13e2fea08c9385145a02ad3fbd59d88

mkdir ${OPERATOR}
opm generate dockerfile ${OPERATOR} \
 -i registry.redhat.io/openshift4/ose-operator-registry:v4.12
opm init ${OPERATOR} --default-channel=${defaultChannel} \
 --output yaml > ${OPERATOR}/index.yaml
opm render ${BUNDLE} --output yaml >> ${OPERATOR}/index.yaml

cat << EOF >> ${OPERATOR}/index.yaml
---
schema: olm.channel
package: ${OPERATOR}
name: ${defaultChannel}
entries:

- name: ${ENTRY}
  skipRange: "${SKIPRANGE}"
EOF

catalog.json 파일을 열면 맨 윗 부분에,

{
    "schema": "olm.package",
    "name": "3scale-operator",
    "defaultChannel": "threescale-2.14",
…
부분이 있다. 여기에서 올바른 operator 이름과 defaultChannel 정보를 가져온다. channel 은 버전에 따라 다른 채널을 사용할 수도 있다.

아래로 조금 더 스크롤해서 channel 정보로 내려온다.

{
    "schema": "olm.channel",
    "name": "threescale-2.14",
    "package": "3scale-operator",
    "entries": [
        {
            "name": "3scale-operator.v0.11.11",
            "skipRange": ">=0.10.0 <0.11.11"
        }
    ]
}

…
필요한 버전의 패키지 이름 정보를 얻어서 entry 변수로 사용한다. skipRange 는 업그레이드시 필요하므로 마찬가지로 변수에 추가한다.

이제 entry 이름으로 검색하며 아래로 내려가면,

{
    "schema": "olm.bundle",
    "name": "3scale-operator.v0.11.11",
    "package": "3scale-operator",
    "image": "registry.redhat.io/3scale-amp2/3scale-rhel7-operator-metadata@sha256:d8e94620237da97e1b65dac4fb616d21d13e2fea08c9385145a02ad3fbd59d88",
...
부분이 나온다. 여기에서 bundle 이미지 정보를 가져온다.



index.yaml 파일 유효성 검사

# opm validate 3scale-operator
# echo $?



operator index 이미지 빌드

# podman build . -f 3scale-operator.Dockerfile -t ecrdev.clouz.io/olm/threescaleoperator-v2.14:v4.12



operator index 이미지 푸시

# podman push ecrdev.clouz.io/olm/threescaleoperator-v2.14:v4.12



operator index 이미지에서 manifests / image 정보를 추출

# oc adm catalog mirror ecrdev.clouz.io/olm/threescaleoperator-v2.14:v4.12 \
 ecrdev.clouz.io/olm \
 -a /root/pull-secret.json \
 --insecure \
 --index-filter-by-os="linux/amd64" \
 --manifests-only



작업 폴더로 이동

# cd manifests-threescaleoperator-v2.14-xxxxx



mapping.txt 파일에서 필요한 image mapping 정보를 우리가 사용하는 구조로 수정하여 mapping-final.txt 파일 생성

# for LINE in $(cat mapping.txt |grep -v "ecrdev.clouz.io/olm/${IMAGE}")
do
arrPART1=(${LINE//=/ })
  arrPART2=(${LINE//@/ })
arrPART3=(${LINE//:/ })
  echo "${arrPART1[0]}=ecrdev.clouz.io/${arrPART2[0]}:${arrPART3[2]}"
done > mapping-final.txt



mapping-final.txt 파일을 이용하여 필요한 이미지를 ecr 로 푸시

# for IMAGE in $(cat mapping-final.txt)
do
oc image mirror -a /root/pull-secret.json --insecure \
 --filter-by-os=.\* \
 ${IMAGE}
done



catalogSource.yaml 수정

# sed "s/test-3scaleoperator/3scaleoperator/" catalogSource.yaml > catalogSource-final.yaml

생성된 catalogSource.yaml의 image가 <namespace>-<image name>으로 되어있기 때문에  수정해야 합니다.

catalogsource name이 image name를 참조하기 때문에, image name이 숫자로 시작한다면 catalogsource 생성이 불가능합니다. 필요 시 변경합니다.



catalogsource 적용

# oc create -f ./catalogSource-final.yaml



설치된 오퍼레이터의 Subscription의 source를 새로 추가한 catalogsource 명으로 변경

# oc get catalogsource -n openshift-marketplace
# oc get csv -n 3scale
# oc get subscriptions.operators.coreos.com -n 3scale
# oc edit subscriptions.operators.coreos.com 3scale-operator -n 3scale
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  creationTimestamp: "2024-02-16T09:21:54Z"
  generation: 1
  labels:
    operators.coreos.com/3scale-operator.3scale: ""
  name: 3scale-operator
  namespace: 3scale
  resourceVersion: "6500010"
  uid: 4eb610db-d74b-4087-85fc-a44828cf1473
spec:
  channel: threescale-2.13
  installPlanApproval: Manual
  name: 3scale-operator
  source: threescaleoperator-v2.14
  sourceNamespace: openshift-marketplace
  startingCSV: 3scale-operator.v0.11.11

source: redhat-threescale-v213-operator -> threescaleoperator-v2.14 (새로운catalogsource) 로 변경


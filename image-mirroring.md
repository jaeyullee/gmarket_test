catalogsource/my-operator-catalog 에 여러 operator 가 묶여 있어서 개별 업그레이드가 매우 어렵다. operator 단위로 catalogsource 를 분리하고 싶으나, 별도로 만들어도 중복으로 보여질 뿐, 설치된 operator (subscription) 이 변경되지 않는다.
→ 해결방안

설치된 operator 를 삭제해도 subscription 등은 설치된 상태로 남는다.

Warning alert:CatalogSource removed
The CatalogSource for this Operator has been removed. The CatalogSource must be added back in order for this Operator to receive any updates.

Upgrade status / Cannot update / CatalogSource not found

targeted catalogsource openshift-marketplace/custom-operator-oadp missing

constraints not satisfiable: no operators found from catalog custom-operator-oadp in namespace openshift-marketplace referenced by subscription redhat-oadp-operator, subscription redhat-oadp-operator exists
등의 에러가 나는 상태이지만, 설치된 operator 는 설치된 상태로 유지된다.
일단 3scale-operator 2.11 으로 유지 가능하다.

몇가지 테스트 하다가 알게 되었는데, subscription 의 속성을 변경하면 catalogsource 갈아타기가 가능하다.

```
# oc edit subscriptions.operators.coreos.com redhat-oadp-operator -n openshift-adp
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
name: redhat-oadp-operator
namespace: openshift-adp
spec:
channel: stable-1.3
installPlanApproval: Automatic
name: redhat-oadp-operator
source: custom-operator-oadp -> custom-operator-oadp2 (새로운catalogsource) 로 변경
sourceNamespace: openshift-marketplace
startingCSV: oadp-operator.v1.2.3
```

이미 설치된 subscription 에서 source 를 custom-operator-oadp2 으로 변경하면 새로운 source 로 인식하고
업그레이드도 된다.

이 방법으로 catalogsource 를 하나씩 분리하자!

(Red Hat 에도 KB 로 있었네.. https://access.redhat.com/solutions/6980347)

4. 업그레이드 전 점검사항
   Deprecated API endpoints in use
   \*deprecated api check 'endpointslices.v1beta1.discovery.k8s.io': [warning] - reason: API is announced to be remove in K8s 1.25, but still called by:
   "system:serviceaccount:metallb-system:speaker" within the last 24h

- deprecated api check 'poddisruptionbudgets.v1beta1.policy': [warning] - reason: API is announced to be remove in K8s 1.25, but still called by:
  "system:serviceaccount:rhsso:rhsso-operator,system:serviceaccount:apim211:3scale-operator" within the last 24h

- deprecated api check 'podsecuritypolicies.v1beta1.policy': [warning] - reason: API is announced to be remove in K8s 1.25, but still called by: "system:kubecontroller-manager,system:admin,system:serviceaccount:kube-system:generic-garbage-collector,system:serviceaccount:openshift-gitops:openshift-gitopsargocd-application-controller" within the last 24h

deprecated API 를 사용하는 subject 가 operator 라서 operator 업그레이드가 선행되어야 함

대상 operator: metallb, sso, 3scale, gitops,

1.24,1.25 에서 remove 되는 api 요청이 있는지 확인한다.

```
$ oc get apirequestcounts |egrep 'NAME| 1\.24| 1\.25'
NAME REMOVEDINRELEASE REQUESTSINCURRENTHOUR REQUESTSINLAST24H
cronjobs.v1beta1.batch 1.25 0 18
endpointslices.v1beta1.discovery.k8s.io 1.25 4 359
horizontalpodautoscalers.v2beta1.autoscaling 1.25 0 0
poddisruptionbudgets.v1beta1.policy 1.25 2 362
podsecuritypolicies.v1beta1.policy 1.25 5 720
```

api 에 요청하는 account (serviceaccount) 도 확인한다.

```
$ for API in $(oc get apirequestcounts -o jsonpath='{range .items[?(@.status.removedInRelease!="")]}{.status.removedInRelease}{"\t"}{.status.requestCount}{"\t"}{.metadata.name}{"\n"}{end}' |grep 1.25 | awk '{print $3}')
do
echo -e  "\n${API}"
oc get apirequestcounts ${API} \
 -o jsonpath='{range .status.last24h..byUser[*]}{..byVerb[*].verb}{","}{.username}{","}{.userAgent}{"\n"}{end}' \
 | sort -k 2 -t, -u | column -t -s ","
done

cronjobs.v1beta1.batch
list system:serviceaccount:dbstreamingv2:default okhttp/4.9.3
get system:serviceaccount:kube-system:generic-garbage-collector kube-controller-manager/v1.23.17+16bcd69
list system:serviceaccount:scdf-demo:default okhttp/3.14.9
list system:serviceaccount:scdf:runasanyuid okhttp/4.9.3

endpointslices.v1beta1.discovery.k8s.io
watch system:serviceaccount:metallb-system:speaker speaker/v0.0.0

horizontalpodautoscalers.v2beta1.autoscaling

poddisruptionbudgets.v1beta1.policy
watch system:serviceaccount:apim211:3scale-operator manager/v0.0.0
watch system:serviceaccount:rhsso:rhsso-operator keycloak-operator/v0.0.0

podsecuritypolicies.v1beta1.policy
list watch system:admin argocd-application-controller/v0.0.0
watch system:kube-controller-manager kube-controller-manager/v1.23.17+16bcd69
get system:serviceaccount:kube-system:generic-garbage-collector kube-controller-manager/v1.23.17+16bcd69
list watch system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller argocd-application-controller/v0.0.0
```

해당 service account 를 사용하는 앱을 찾아서 조치해야 한다.

1. cronjobs.v1beta1.batch

cronjobs.v1beta1.batch 대신에 cronjobs.v1.batch 으로 호출해야 한다. cronjob api 는 k8s 1.21 (ocp 4.8) 에서 GA 되었음.
해당 api 를 호출하는 service account 는SCDF 프로젝트, SCDF 에서 구버전 api 를 호출하고 있음.

SCDF의 kubernetes 호환성 메트릭 확인
https://dataflow.spring.io/docs/installation/kubernetes/compatibility/

놀랍게도 2023년 9월에 릴리즈된 SCDF 2.11.x 부터 k8s 1.25 (ocp 4.12) 를 지원한다.
즉, 지금까지 설치된 모든 SCDF 인스턴스를 2.11.x 로 업그레이드 해야한다.

2. kube-state-metrics

일부 클러스터에서 kube-state-metrics v2.3.0 이미지를 사용중

kube-state-metrics v2.7.0 으로 변경하고, ocp 4.12 (k8s 1.25) 업그레이드 시점에 v2.10.0 으로 변경한다.

5. 기타 주의사항 (추후 업데이트)
   oc 클라이언트 버전은 업그레이드할 버전과 동일한 것을 사용한다. bastion 서버의 openshift-clients 패키지를 먼저 업데이트 한다.
   4.10부터 alertmanager의 replicas가 3 → 2로 변경됨에 따라 업그레이드 후 사용되지 않는 pv, pvc를 수작업으로 제거해야 한다. (업그레이드 후 openshift-monitoring 프로젝트에서 수동으로 제거)
   oc get co에서 모든 오퍼레이터가 정상 상태이어야 업그레이드 진행 가능하다.
   go lang 버전이 올라감에 따라 인증서의 SAN(Subject Alternative Name) 이 있어야 한다. 설치된 인증서에서 SAN(Subject Alternative Name) 내용이 있는지 확인 필요함.
   https://access.redhat.com/documentation/en-us/openshift_container_platform/4.10/html-single/updating_clusters/index#updating-restricted-network-cluster 의 Prerequisites 항목 체크
   4.10 업그레이드 이후 GUI 콘솔에서 catalog (template) 목록이 느리게 나오는 현상이 발생 : helmchartrepositories 객체에서 참조하는 repo 가 모두 인터넷 환경이라서 disconnected 환경에서 발생함. 아래 옵션으로 disable 설정 (disable: true 추가

```
# oc edit helmchartrepositories.helm.openshift.io openshift-helm-charts
apiVersion: helm.openshift.io/v1beta1
kind: HelmChartRepository
metadata:
name: redhat-helm-repo
spec:
connectionConfig:
url: https://redhat-developer.github.io/redhat-helm-charts
disabled: true
```

```
# oc edit helmchartrepositories.helm.openshift.io redhat-helm-repo
apiVersion: helm.openshift.io/v1beta1
kind: HelmChartRepository
metadata:
name: openshift-helm-charts
spec:
connectionConfig:
url: https://charts.openshift.io
disabled: true
```

6. Operator Index (CatalogSource) 만들기
작업서버: fusiond3h01gm

0. 준비물

opm https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.12/ 에서 다운로드

auth 파일을 /root/.docker/config.json 으로 저장

1. oc adm catalog mirror 명령으로 catalog.json 파일 추출

```
oc adm catalog mirror \
 registry.redhat.io/redhat/redhat-operator-index:v4.12 \
 ecr.clouz.io/olm \
 -a /root/pull-secret.json \
 --insecure \
 --index-filter-by-os="linux/amd64" \
 --manifests-only
```
끝까지 기다리지 말고 /tmp/12345... 나오고 이미지를 미러링하는 단계에서 ctrl-C 눌러서 중단하고 /tmp/12345... 폴더를 확인

2. 환경변수 설정 catalog.json 파일을 참고해서 아래의 변수를 설정한다.

```
OPERATOR=servicemeshoperator
IMAGE=servicemeshoperator
defaultChannel=stable
ENTRY=servicemeshoperator.v2.3.3
SKIPRANGE=">=1.0.2 <2.3.3-0"
BUNDLE=registry.redhat.io/openshift-service-mesh/istio-rhel8-operator-metadata@sha256:8813c0401dcc3056a735ba9d435c85b234bbad7a6b85142b627bbb0d71233944
```

catalog.json 파일을 열면 맨 윗 부분에,

```
{
"schema": "olm.package",
"name": "servicemeshoperator",
"defaultChannel": "stable",
..
```

부분이 있다. 여기에서 올바른 operator 이름과 defaultChannel 정보를 가져온다. channel 은 버전에 따라 다른 채널을 사용할 수도 있다.

아래로 조금 더 스크롤해서 channel 정보로 내려온다.

```
{
"schema": "olm.channel",
"name": "stable",
"package": "servicemeshoperator",
"entries": [
{
"name": "servicemeshoperator.v2.0.8",
"replaces": "servicemeshoperator.v2.0.7.1",
"skipRange": ">=1.0.2 <2.0.8-0"
},
...
{
"name": "servicemeshoperator.v2.3.3",
"replaces": "servicemeshoperator.v2.3.2",
"skipRange": ">=1.0.2 <2.3.3-0"
},
...
```

필요한 버전의 패키지 이름 정보를 얻어서 entry 변수로 사용한다. skipRange 는 업그레이드시 필요하므로 마찬가지로 변수에 추가한다.

이제 entry 이름으로 검색하며 아래로 내려가면,

```
{
"schema": "olm.bundle",
"name": "servicemeshoperator.v2.3.3",
"package": "servicemeshoperator",
"image": "registry.redhat.io/openshift-service-mesh/istio-rhel8-operator-metadata@sha256:8813c0401dcc3056a735ba9d435c85b234bbad7a6b85142b627bbb0d71233944",
"properties": [
...
```

부분이 나온다. 여기에서 bundle 이미지 정보를 가져온다.

3. index.yaml 생성, 이미지 생성, push

* operator 의 index.yaml 을 저장할 폴더를 생성
```
mkdir ${OPERATOR}
```

* operator 용 dockerfile 생성, base 는 ose-operator-registry 이미지를 사용한다.
```
~/opm generate dockerfile ${OPERATOR} -i registry.redhat.io/openshift4/ose-operator-registry:v4.12
```

* operator 용 defaultchannel 정보 등 header 부분을 생성
```
~/opm init ${OPERATOR}  --default-channel=${defaultChannel} --description=./README.md --icon=./openshift.svg --output yaml > ${OPERATOR}/index.yaml
```

* bundle 이미지로부터 관련 이미지 정보를 가져와서 index.yaml 파일에 추가
```
~/opm render ${BUNDLE} --output=yaml >> ${OPERATOR}/index.yaml
```

* index.yaml 에 entry (패키지) 정보를 추가
```
# cat << EOF >> ${OPERATOR}/index.yaml
schema: olm.channel
package: ${OPERATOR}
name: ${defaultChannel}
entries:

- name: ${ENTRY}
    skipRange: "${SKIPRANGE}"
  EOF
```

* index.yaml 파일 유효성 검사
```
~/opm validate ${OPERATOR}
```

* index.yaml 파일에 entry 정보가 올바르게 추가되었는지 눈으로 확인
```
tail ${OPERATOR}/index.yaml
```

* operator index 이미지 빌드
```
podman build . -f ${OPERATOR}.Dockerfile -t ecrdev.clouz.io/olm/${IMAGE}:v4.12
```

* operator index 이미지 푸시
```
podman push ecrdev.clouz.io/olm/${IMAGE}:v4.12
```

4. 필요한 이미지 미러링

* 기존 작업 폴더가 남아있으면 삭제
```
\rm -rf manifests-${IMAGE}\*
```

* operator index 이미지에서 manifests / image 정보를 추출
```
oc adm catalog mirror ecrdev.clouz.io/olm/${IMAGE}:v4.12 \
 ecrdev.clouz.io/olm \
 -a /root/pull-secret.json \
 --insecure \
 --index-filter-by-os="linux/amd64" \
 --manifests-only
```

* 작업 폴더로 이동
```
cd manifests-${IMAGE}\*
```

* mapping.txt 파일에서 필요한 image mapping 정보를 우리가 사용하는 구조로 수정하여 mapping-final.txt 파일 생성
```
for LINE in $(cat mapping.txt |grep -v "ecrdev.clouz.io/olm/${IMAGE}")
do
arrPART1=(${LINE//=/ })
  arrPART2=(${LINE//@/ })
arrPART3=(${LINE//:/ })
  echo "${arrPART1[0]}=ecrdev.clouz.io/${arrPART2[0]}:${arrPART3[2]}"
done > mapping-final.txt
```

* mapping-final.txt 파일을 이용하여 필요한 이미지를 ecr 로 푸시
```
for IMAGE in $(cat mapping-final.txt)
do
oc image mirror -a /root/pull-secret.json --insecure \
 --filter-by-os=.\* \
 ${IMAGE}
done
```

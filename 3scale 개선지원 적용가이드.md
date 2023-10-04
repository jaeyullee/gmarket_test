# Gmarket 3scale 개선지원 적용가이드
  
## 목차
1. [Redis AOF 기능 비활성화](#1-Redis-AOF-기능-비활성화)
2. [Openshift Prometheus를 활용한 3scale API 요청 데이터 조회](#2-Openshift-Prometheus를-활용한-3scale-API-요청-데이터-조회)
  
  
## 1. Redis AOF 기능 비활성화
* redis-conf ConfigMap 수정 및 변경사항 적용
```
# oc edit cm redis-config -n 3scale
# oc get cm redis-config -n 3scale -oyaml | grep appendonly
# oc get po -n 3scale | grep redis
# oc delete po <redis-pod-name> -n 3scale
```

> redis-pod를 삭제하여 변경된 ConfigMap이 mount 된 redis-pod로 재시작하도록 합니다.

* redis-pod의 AOF 기능 비활성화 되었는지 확인
```
# oc exec -it <redis-pod-name> -n 3scale -- cat /etc/redis.d/redis.conf
# oc rsh <redis-pod-name>
$ redis-cli -h 127.0.0.1 -p 6379
$ INFO persistence
```

> 3scale 2.11 와 2.12 버전 Operator 기준으로, Operator에 의한 ConfigMap에 대한 Reconcile이 동작하지 않음을 확인했습니다.  
> 다만 기술적으로는 추후 Reconcile 되도록 변경하는 것은 가능하므로 패치 시 확인이 필요합니다.


## 2. Openshift Prometheus를 활용한 3scale API 요청 데이터 조회
* user workload에 대한 모니터링 허용
```
# vi openshift-cluster-monitoring-configmap.yaml
…
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
…
# oc -n openshift-monitoring apply -f openshift-cluster-monitoring-configmap.yaml
# watch oc get po -n openshift-monitoring
```

> ConfigMap 변경 시 적용을 위한 Pod 재시작 확인이 필요합니다.

* 모니터링 대상 프로젝트에 대한 label 설정
```
# oc label namespace 3scale monitoring=apicast
```

* metric 포트에 대한 service 설정
```
# oc expose dc/apicast-staging --name=metrics-staging-apicast --port=9421 -n 3scale
# oc expose dc/apicast-production --name=metrics-production-apicast --port=9421 -n 3scale
# oc label svc metrics-staging-apicast monitoring=apicast -n 3scale
# oc patch svc/metrics-staging-apicast -p '{"spec":{"ports":[{"name":"metrics","port":9421,"protocol":"TCP","targetPort":9421}]}}' -n 3scale
# oc label svc metrics-production-apicast monitoring=apicast -n 3scale
# oc patch svc/metrics-production-apicast -p '{"spec":{"ports":[{"name":"metrics","port":9421,"protocol":"TCP","targetPort":9421}]}}' -n 3scale
# oc get project 3scale -o jsonpath='{.metadata.labels}'
# oc get svc/metrics-staging-apicast -n 3scale -o jsonpath='{.metadata.labels}{"\n"}{.spec.ports}'
# oc get svc/metrics-production-apicast -n 3scale -o jsonpath='{.metadata.labels}{"\n"}{.spec.ports}'
```

> 3scale apicast는 9421 포트를 통해 metric 정보를 제공합니다.

* servicemonitor 객체 생성
```
# vi apicast-service-monitor.yaml
…
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    app: apicast
  name: apicast-monitor
  namespace: 3scale
spec:
  selector:
    matchLabels:
      monitoring: apicast
  endpoints:
  - interval: 5s
    path: /metrics
    port: metrics
    scheme: http
…
# oc -n 3scale apply -f apicast-service-monitor.yaml
# oc get pods -n 3scale
```

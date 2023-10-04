# Gmarket 3scale 개선지원 적용가이드

## 1. Redis AOF 기능 비활성화
    * redis-conf ConfigMap 수정 및 번경사항 적용
    ```
    # oc edit cm redis-config -n 3scale
    # oc get cm redis-config -n 3scale -oyaml | grep appendonly
    # oc get po -n 3scale | grep redis
    # oc delete po <redis-pod-name> -n 3scale
    ```
> redis-pod를 삭제하여 변경된 ConfigMap이 mount 된 redis-pod로 재시작하도록 합니다.

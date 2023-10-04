# Gmarket 3scale 개선지원 적용가이드

<목차>

   
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
    
    > 3scale 2.11 버전 및 2.12 버전 Operator 설치 기준, Operator에 의한 ConfigMap에 대한 Reconcile이 동작하지 않음을 확인했습니다.
    > 다만 기술적으로는 추후 Reconcile 되도록 변경하는 것은 가능하므로 패치 시 확인이 필요합니다.

   
## 2. 

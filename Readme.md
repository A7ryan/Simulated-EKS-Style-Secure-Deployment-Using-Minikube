# Setup Instructions:

1. Start up the minikube
- minikube start --cpus=2 --memory=4096 --addons=ingress,metrics-server

##

2. Enable the Ingress
- minikube addons enable ingress

##

3. Check once if its running
- kubectl get pods -n ingress-nginx

##

4. List the Helm Charts Available
- helm repo list

##

5. Add Prometheus/Grafana using Helm Chart
- helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

##

6. Apply the Kustomize file
- kubectl apply -k .

##

7. Create a bucket into MiniO
- kubectl exec -it -n application $(kubectl get pod -n application -l app=minio -o jsonpath='{.items[0].metadata.name}') -- /bin/sh
- mc alias set myminio http://localhost:9000 minio minioadmin
- mc mb myminio/testbucket

##

8. Prove Auth-service cannot access the bucket
- kubectl exec -it -n application $(kubectl get pod -n application -l app=auth -o jsonpath='{.items[0].metadata.name}') -- /bin/sh
- curl http://minio.application.svc.cluster.local:9000/testbucket
- (It will output Access Denied)

##

9. NOTE: The data-service (image - hashicorp/http-echo:latest) does not have any ssh
- Solution:  
    - i.  Either Create Custom Dockerfile
    - ii. Use the new pod with service account (I have created data-servica-sa)

##

10. Creating a Temporary pod
- kubectl apply -f test-data-access.yaml

##

11. Try to access now:
- kubectl exec -it -n application test-data-access -- /bin/sh
- aws configure set s3.endpoint_url http://minio.application.svc.cluster.local:9000
- aws configure set s3api.endpoint_url http://minio.application.svc.cluster.local:9000

##

12. I will create a demo .txt file and will upload that to that MiniO Bucket
- echo "test" > testfile.txt
- aws --endpoint-url=http://minio.application.svc.cluster.local:9000 s3 cp testfile.txt s3://testbucket/
- aws --endpoint-url=http://minio.application.svc.cluster.local:9000 s3 ls s3://testbucket

##

13. Success just login to MiniO
- kubectl exec -it -n application $(kubectl get pod -n application -l app=minio -o jsonpath='{.items[0].metadata.name}') -- /bin/sh

##

14. check the data dir and try to find bucket and its object
- cd ~
- ls 
- cd data
- cd <bucket-name>
- ls

##

15. Auth-service is leaking Authorization (find it out)
- kubectl exec -it -n application $(kubectl get pod -n application -l app=auth -o jsonpath='{.items[0].metadata.name}') -- /bin/sh

- curl -H "Authorization: Bearer fake-token-123" http://auth-service.application.svc.cluster.local/headers
(it show show good output)

##

16. Run the Node Exporter
- docker run -d \
  --name node-exporter \
  -p 9100:9100 \
  --restart unless-stopped \
  prom/node-exporter:latest

##

17. Run the Prometheus Server
- docker run -d \
  --name prometheus \
  -p 9090:9090 \
  -v ~/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  --restart unless-stopped \
  prom/prometheus:latest

##

18. Run the Grafana Server
- docker run -d \
  --name grafana \
  -p 3000:3000 \
  --restart unless-stopped \
  grafana/grafana:latest

##

19. Filter the Queries according to Requirement*
- Query:
    - System CPU Usage: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
    - System Memory Usage: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100
    - HTTP Rate Request: rate(http_requests_total[5m])
    - HTTP Error Rate: rate(http_requests_total{status=~"5.."}[5m])
    - Process Restarts: changes(process_start_time_seconds{job="application"}[1h])
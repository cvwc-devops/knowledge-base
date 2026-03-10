# Debugging Checklist 

## Step 1:  Start here, every time.
Run ```kubectl logs api-server-7d9f8b-xkz2p -f```
If your pod runs multiple containers, “sidecars are secondary containers that run alongside your main app, commonly used for logging agents, proxies like Envoy, or secret injectors.” 
Add -c to target the right one: ```kubectl logs api-server-7d9f8b-xkz2p -c nginx-sidecar```. 
Check your log level; if it's set to INFO in production, bump it temporarily to DEBUG for the failing pod. Look for uncaught exceptions, connection refusals, 
or anything that says "missing config." If the pod restarts constantly and you can’t catch the logs in time, use 
```kubectl logs api-server-7d9f8b-xkz2p --previous```
That shows you why the last run died.

## Step 2: Health & Readiness Probes
A misconfigured liveness probe kills your container. A misconfigured readiness probe pulls it from the Service. 
Both look like “Kubernetes is randomly restarting my pod,” when it’s your problem, not the cluster’s.
Run ```kubectl get pod <pod> -o yaml``` and find livenessProbe and readinessProbe. 
Then hit the same endpoints from inside the cluster: ```kubectl exec <pod> -- curl localhost:<port>/health```. 
Confirm the app is listening on the probe port and that the startup time fits within initialDelaySeconds.
If the probe fires before the app is ready, you get a restart loop. The fix is usually raising initialDelaySeconds or adding a startupProbe.

## Step 3: Environment & Config
Run ```kubectl describe pod <pod>``` and check the env section. Then, ```kubectl exec <pod> -- env``` to see what the process actually receives, not what you think you deployed.
If config is file-based, check the mount path and read the file contents inside the container. A stale or empty Secret, a key in the wrong namespace, or a ConfigMap overridden by a later deployment will produce failures that look like application bugs.

## Step 4: Resource Limits & Scheduling
Check ```kubectl describe pod <pod>``` and read the Events section. Look for OOMKilled, Evicted, or FailedScheduling.
A container with no memory limit can consume node memory until it gets killed. The exit looks like a crash. Pending pods often mean no node matches the resource requests, or there’s a taint/toleration mismatch. ```Run kubectl top pod``` If metrics are available, compare actual usage against your limits.

## Step 5: Networking & DNS
From another pod in the cluster: ```nslookup <service>.<namespace>.svc.cluster.local```.
Then ```curl -v http://<service>.<namespace>:<port>```.
Confirm the Service has endpoints: ```kubectl get endpoints <service>```. If the endpoints list is empty, no pod is passing the readiness check, or no pod matches the Service selector.
Wrong port in the Service spec and missing labels on the pod are the two most common causes.

## Step 6: Storage & Mounts
Run ```kubectl describe pod <pod-name>``` and review the Volumes, Mounts, and Events sections, then verify PVC status with kubectl get pvc to confirm the claim is Bound. Exec into the container with ```kubectl exec -it <pod-name> -- /bin/sh``` and check that the mount path exists and is writable if the application needs write access. Read-only mounts, incorrectfsGroup, or a PVC stuck in Pending (often due to a missing StorageClass or insufficient capacity) can trigger errors like "permission denied" or "no space left on device", which are frequently mistaken for application-level failures.

## Step 7: Deployment & Rollout
Run ```kubectl rollout status deployment/<name>``` to confirm the deployment completed. Then run ```kubectl describe pod <pod>``` and verify the image tag or digest the container is actually running. Use ```kubectl get rs``` (ReplicaSets) to check whether an older ReplicaSet is still serving traffic or a new one is stuck rolling out. When a rollout fails or stalls, the cluster may continue running the old image, which leads to confusion when a new feature appears “missing.”

## Step 8: Cluster & Node Sanity
Only after the first seven steps are clean does it make sense to look here.
```kubectl get nodes``` and check for NotReady or SchedulingDisabled. Then ```kubectl get events -A --sort-by='.lastTimestamp'``` for recent cluster-wide events. Look for node pressure—memory, disk, PID, or kubelet errors. This is where CNI bugs, CSI driver failures, and control plane issues live.

# App 8-STEP DEBUGGING CHECKLIST 

## Step 1:
Application logs: ```kubectl logs <pod>```; errors, stack traces, log level
## Step 2: Health & readiness
Check liveness/readiness probes and /health endpoints. Misconfigured probes can cause restart loops even when the app works.
## Step 3: Environment & config
Verify environment variables, ConfigMaps, Secrets, and mounted config files. Check requests/limits, OOMKilled, CPU throttling, or eviction events.
## Step 4: Resource limits
describe pod, ```kubectl describe pod <pod>```, Check requests/limits, OOM/eviction events
## Step 5: Networking & DNS
Test connectivity from inside the pod
```
kubectl exec -it <pod> -- nslookup <service>
kubectl exec -it <pod> -- curl <service>
```
## Step 6: Storage & mounts
Confirm PVC status, mount paths, and write permissions.
## Step 7: Deployment & rollout
```kubectl rollout status deployment/<name>```
Verify the image tag and active ReplicaSet.
## Step 8: Cluster & nodes: kubectl get nodes
```kubectl get events -A```
Look for node pressure, scheduling failures, or cluster-level issues.

---

### Emergency Commands

```bash
# System Health Check
top -p $(pgrep -d',' -f your_app)
free -h && df -h
netstat -tulpn | grep LISTEN

# Container Quick Debug
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker logs --tail 100 -f container_name

# Kubernetes Emergency
kubectl get pods --all-namespaces | grep -v Running
kubectl top nodes && kubectl top pods
```

### Installation

```bash
# Clone the repository
git clone https://github.com/Osomudeya/DevOps-Troubleshooting-Toolkit.git
cd DevOps-Troubleshooting-Toolkit

# Make scripts executable
chmod +x scripts/*.sh

# Optional: Add to PATH for global access
echo 'export PATH=$PATH:'$(pwd)'/scripts' >> ~/.bashrc
source ~/.bashrc
```

## Platform Guides

### Linux Systems
| Component | Quick Access | Description |
|-----------|--------------|-------------|
| **Linux Commands** | [`linux/linux-commands.md`](/docs/k8s/linux/linux-commands.md) | Essential system diagnostics and troubleshooting |

### Container Platforms
| Platform | Quick Access | Key Features |
|----------|--------------|--------------|
| **Docker** | [`containers/docker-troubleshooting.md`](/docs/k8s/containers/docker-troubleshooting.md) | Container lifecycle, networking, volumes |

### Kubernetes
| Component | Quick Access | Coverage |
|-----------|--------------|----------|
| **Kubernetes** | [`kubernetes/kubernetes-troubleshooting.md`](/docs/k8s/kubernetes/kubernetes-troubleshooting.md) | Cluster management, workloads, networking |

### Cloud Providers
| Provider | Quick Access | Specializations |
|----------|--------------|-----------------|
| **AWS** | [`cloud/aws-troubleshooting.md`](/docs/k8s/cloud/aws-troubleshooting.md) | EKS, Lambda, RDS, VPC troubleshooting |
| **GCP** | [`cloud/gcp-troubleshooting.md`](/docs/k8s/cloud/gcp-troubleshooting.md) | GKE, Cloud Functions, networking |
| **Azure** | [`cloud/azure-troubleshooting.md`](/docs/k8s/cloud/azure-troubleshooting.md) | AKS, App Services, resource groups |
| **Multi-Cloud** | [`cloud/multi-cloud-strategies.md`](/docs/k8s/cloud/multi-cloud-strategies.md) | Cross-platform strategies |

### Databases
| Database | Quick Access | Focus Areas |
|----------|--------------|-------------|
| **Database Troubleshooting** | [`databases/database-troubleshooting.md`](/docs/k8s/databases/database-troubleshooting.md) | Connection, performance, backup issues |

### Observability
| Tool | Quick Access | Coverage |
|------|--------------|----------|
| **Prometheus & Grafana** | [`observability/prometheus-and-grafana.md`](/docs/k8s/observability/prometheus-and-grafana.md) | Monitoring, alerting, dashboards |

## Common Issues

### Critical System Issues
[`linux/linux-commands.md`](/docs/k8s/linux/linux-commands.md)

#### High Load Average
```bash
# Quick diagnosis
uptime && cat /proc/loadavg
ps aux --sort=-%cpu | head -10
iostat -x 1 5

# Deep dive
sar -u 1 10  # CPU utilization
sar -d 1 10  # Disk activity
```

#### Out of Memory (OOM)
```bash
# Check OOM killer logs
dmesg | grep -i "killed process"
journalctl -u your-service | grep -i oom

# Memory analysis
free -h && cat /proc/meminfo
ps aux --sort=-%mem | head -10
```

#### Disk Space Full
```bash
# Find large files and directories
df -h
du -sh /* 2>/dev/null | sort -hr | head -10
find / -type f -size +1G 2>/dev/null

# Log rotation check
journalctl --disk-usage
```

### Container Issues
[`containers/docker-troubleshooting.md`](/docs/k8s/containers/docker-troubleshooting.md)

#### Container Won't Start
```bash
# Debug container startup
docker logs container_name
docker inspect container_name
docker run --rm -it image_name /bin/sh

# Resource constraints
docker stats container_name
```

#### Container Networking
```bash
# Network debugging
docker network ls
docker inspect network_name
docker exec container_name netstat -tulpn
```

### Kubernetes Issues
[`kubernetes/kubernetes-troubleshooting.md`](/docs/k8s/kubernetes/kubernetes-troubleshooting.md)

#### Pods Stuck in Pending
```bash
# Check pod status
kubectl describe pod pod_name
kubectl get events --sort-by=.metadata.creationTimestamp

# Resource availability
kubectl top nodes
kubectl describe nodes
```

#### Service Not Accessible
```bash
# Service debugging
kubectl get svc,ep service_name
kubectl describe svc service_name
kubectl get pods -l app=your_app -o wide
```

### Network Issues

#### DNS Resolution Failures
```bash
# DNS troubleshooting
nslookup domain.com
dig domain.com
systemd-resolve --status
```

#### Connection Timeouts
```bash
# Network connectivity
telnet host port
nc -zv host port
traceroute host
```

### Database Issues

#### Connection Problems
```bash
# Database connection check
mysql -h hostname -u username -p -e "SELECT 1"
psql -h hostname -U username -c "SELECT 1"
mongo --host hostname --eval "db.stats()"
```

[`databases/database-troubleshooting.md`](/docs/k8s/databases/database-troubleshooting.md)

## 📊 Troubleshooting Scenarios

**Complete Troubleshooting Scenarios**
[`scenarios/scenarios.md`](scenarios/scenarios.md)

## 🛠️ Useful Scripts

### Available Scripts
- [`scripts/auto-clone-all-repos.sh`](scripts/auto-clone-all-repos.sh) - Clone all repositories from an organization
- [`scripts/auto-pull-all-repos.sh`](scripts/auto-pull-all-repos.sh) - Update all local repositories
- [`scripts/k8s-tailogs.sh`](scripts/k8s-tailogs.sh) - Stream logs from multiple Kubernetes pods
- [`scripts/kubernetes-events.sh`](scripts/kubernetes-events.sh) - Monitor Kubernetes events in real-time
- [`scripts/kubernetes-tools.sh`](scripts/kubernetes-tools.sh) - Install essential Kubernetes tools

### Usage Examples
```bash
# Repository management
./scripts/auto-clone-all-repos.sh    # Clone all org repositories
./scripts/auto-pull-all-repos.sh     # Update all local repositories

# Kubernetes tools
./scripts/kubernetes-events.sh       # Monitor K8s events real-time
./scripts/k8s-tailogs.sh            # Stream logs from multiple pods
./scripts/kubernetes-tools.sh       # Install essential K8s tools
```

## Content Organization

```
DevOps-Troubleshooting-Toolkit/
├── linux/                     # Linux system troubleshooting
│   └── linux-commands.md      # Essential Linux commands
├── containers/                 # Container platform issues
│   └── docker-troubleshooting.md # Docker troubleshooting guide
├── kubernetes/                 # K8s cluster and workload problems
│   └── kubernetes-troubleshooting.md # Kubernetes troubleshooting
├── cloud/                      # Cloud provider specific guides
│   ├── aws-troubleshooting.md  # AWS troubleshooting
│   ├── azure-troubleshooting.md # Azure troubleshooting
│   ├── gcp-troubleshooting.md  # GCP troubleshooting
│   └── multi-cloud-strategies.md # Multi-cloud strategies
├── databases/                  # Database troubleshooting
│   └── database-troubleshooting.md # Database issues
├── observability/              # Monitoring, logging, and tracing
│   └── prometheus-and-grafana.md # Prometheus & Grafana guide
├── scenarios/                  # End-to-end troubleshooting scenarios
│   └── scenarios.md           # Real-world scenarios
├── scripts/                    # Automated troubleshooting scripts
│   ├── auto-clone-all-repos.sh
│   ├── auto-pull-all-repos.sh
│   ├── k8s-tailogs.sh
│   ├── kubernetes-events.sh
│   └── kubernetes-tools.sh
└── assets/
    ├── images/                 # Repository images and diagrams
    └── cheatsheets/           # Printable reference materials
```

## Quick Tests & Validation

### Database Connectivity
```bash
# MySQL/MariaDB
mysql -h hostname -u username -p -e "SELECT VERSION(), NOW();"

# PostgreSQL
psql -h hostname -U username -c "SELECT version();"

# MongoDB
mongosh --host hostname --eval "db.runCommand({ping: 1})"

# Redis
redis-cli -h hostname ping
```

### Service Health Checks
```bash
# HTTP services
curl -I http://service-endpoint/health
wget --spider http://service-endpoint/health

# TCP services
nc -zv hostname port
telnet hostname port
```

### Container Registry Access
```bash
# Docker Hub
docker pull hello-world

# Private registry
docker login registry.company.com
docker pull registry.company.com/app:latest
```

## Observability & Monitoring

### Prometheus & Grafana
```bash
# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq .

# Grafana API health
curl -H "Authorization: Bearer $GRAFANA_TOKEN" http://localhost:3000/api/health
```
**Full Guide**: [`observability/prometheus-and-grafana.md`](observability/prometheus-and-grafana.md)

## 🔄 Recently Updated

| File | Last Updated | Changes |
|------|-------------|---------|
| [`kubernetes/kubernetes-troubleshooting.md`](kubernetes/kubernetes-troubleshooting.md)  |
| [`cloud/aws-troubleshooting.md`](cloud/aws-troubleshooting.md) |
| [`observability/prometheus-and-grafana.md`](observability/prometheus-and-grafana.md) | 
| [`scripts/kubernetes-tools.sh`](scripts/kubernetes-tools.sh) | 




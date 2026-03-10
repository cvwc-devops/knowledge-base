## 1. Process Substitution: Compare Anything, Anywhere, In Real-Time
Most engineers know about pipes (|) and redirects (>, <), but process substitution (<()) is the secret weapon for real-time system comparison.

### The Problem
You suspect different servers are behaving differently, but manually checking logs across multiple hosts is tedious and error-prone.

### The Solution
**Compare live logs from two servers simultaneously**
```
diff <(ssh server1 "tail -f /var/log/app.log") <(ssh server2 "tail -f /var/log/app.log")
```
**Monitor multiple Kubernetes pods side-by-side**
```
paste <(kubectl logs -f pod1) <(kubectl logs -f pod2) | column -t
```
**Compare configuration files across environments instantly**
```
diff <(curl -s https://prod.api.com/config) <(curl -s https://staging.api.com/config)
```

## 2. History Expansion: Your Incident Response Superpower
When every second counts during an outage, retyping long commands is both inefficient and error-prone. History expansion is your time machine.
### What Matters
bash
**Rerun the last command that contained specific text**
```
!kubectl      # Runs the most recent kubectl command
!grep         # Runs the most recent grep command
```

**Fix typos instantly without retyping**
```
^tpyo^typo    # Replaces 'tpyo' with 'typo' in the last command
```
**Add sudo to your previous command**
```
sudo !!       # Reruns last command with sudo
```

**Reuse arguments from previous commands**
```
cp /var/log/complex-service-name.log !$    # !$ = last argument
rm !^         # !^ = first argument from previous command
```

**Add toyour .bashrc**
```
# Enable history expansion with space
bind Space:magic-space
```

## 3. Brace Expansion: Mass Operations Made Simple
Brace expansion is bash’s built-in way to generate sequences and variations, perfect for batch operations across multiple services, environments, or time periods.

### Essential Patterns

**Create multiple backup directories at once**
```
mkdir backup-{db,logs,config}-$(date +%Y%m%d)
Expands to: mkdir backup-db-20260305 backup-logs-20260305 backup-config-20260305
```

**Check health across all environments**
```
for env in {prod,staging,dev}; do 
    echo "=== $env ===" 
    curl -s https://$env.api.com/health | jq '.status'
done
# Quick backup with timestamp
cp nginx.conf{,.backup-$(date +%s)}
# Expands to: cp nginx.conf nginx.conf.backup-2026030567
# Download logs from a date range
wget https://logs.example.com/app-2025-{01..12}-{01..31}.log

OR
cp $filename ${filename%.backup*}
```

**Mass service restart across multiple hosts**
```
for host in web-{01..09}; do
    ssh $host "sudo systemctl restart nginx"
done
```

**Create directory structure for new service**
```
mkdir -p service-{api,worker,scheduler}/{config,logs,data}
```
## 4. Command Substitution with Error Handling
Command substitution ($()) is common, but most people don't use it strategically for dynamic infrastructure operations.

**Dynamic Operations**
### Get the running pod name and exec into it immediately
```
kubectl exec $(kubectl get pods -l app=myapp -o jsonpath='{.items[0].metadata.name}') -- bash
```

**Alert based on current system state**
```
alert_threshold=$(curl -s http://metrics.com/thresholds | jq .cpu_alert)
current_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
[ ${current_cpu%.*} -gt $alert_threshold ] && \
    slack-notify "CPU Alert: $current_cpu% (threshold: $alert_threshold%)"
```

**Chain operations with validation**
```
pod_name=$(kubectl get pods --no-headers | grep Running | head -1 | awk '{print $1}') && \
kubectl logs $pod_name --tail=100 | grep ERROR | tail -5
```

**Error Handling Pattern**
```
echo Only proceed if the previous command succeeded
if pod_name=$(kubectl get pods -l app=critical --no-headers 2>/dev/null); then
    echo "Found pod: $pod_name"
    kubectl describe pod $pod_name
else
    echo "No pods found - check deployment status"
    kubectl get deployments -l app=critical
fi
```

## 5. Parameter Expansion: Configuration Management Without External Tools
**Setting Smart Defaults**
```
# Environment variables with fallbacks
DATABASE_URL=${DATABASE_URL:-postgresql://localhost:5432/app}
LOG_LEVEL=${LOG_LEVEL:-INFO}
TIMEOUT=${TIMEOUT:-30}
REPLIAS=${REPLICAS:-3}
```

**Use in deployment scripts**
```
kubectl create deployment myapp --image=myapp:${VERSION:-latest} \
    --replicas=${REPLICAS} \
    --env="DATABASE_URL=${DATABASE_URL}" \
    --env="LOG_LEVEL=${LOG_LEVEL}"
```

**String Manipulation Magic**
```
# Extract information from file paths
config_file="/etc/myapp/prod/database.conf"
filename=${config_file##*/}        # "database.conf"
directory=${config_file%/*}        # "/etc/myapp/prod"
environment=${directory##*/}       # "prod"
```

**Advanced Patterns**
```
# Parse service URLs
service_url="https://api-prod-us-east-1.example.com"
region=${service_url#*-prod-}      # "us-east-1.example.com"
region=${region%%.*}               # "us-east-1"
# Conditional deployments
deploy_to=${1:-staging}            # Use first argument or default to staging
echo "Deploying to: $deploy_to"
kubectl apply -f manifests/${deploy_to}/ --namespace=${deploy_to}
```

**SRE One-Liner**
```
watch -n1 '
echo "=== CPU/MEMORY ==="
top -bn1 | head -5
echo -e "\n=== DISK USAGE ==="
df -h | grep -v tmpfs
echo -e "\n=== NETWORK CONNECTIONS ==="
netstat -tuln | grep LISTEN | head -5
echo -e "\n=== RECENT ERRORS ==="
tail -n3 /var/log/syslog | grep -i error
'
```

## AWS Services 

```
Service                Pri DevOps Role
EC2                    Compute, autoscaling, AMIs
VPC                    Networking, isolation, security
EBS                    Stateful block storage
S3                     Artifacts, logs, backups
IAM                    Identity & access control
CloudWatch             Monitoring & observability 
Lambda                 Event-driven automation
CodeBuild              CI build runner
AWS Config             Compliance & drift detection
Billing & Cost         FinOps & optimization
KMS                    Encryption & key management
CloudTrail             Audit & governance
EKS                    Kubernetes orchestration
Fargate                Serverless containers
ELK / OpenSearch       Log analytics & search
```

## Daily / Weekly DevOps Checklist

- Security audits (IAM, S3, SGs)
- Backups & snapshots
- Dashboard reviews
- Cost anomaly checks
- Compliance & drift review


## Linux Essentials
### Basic Commands
```
ls -la                  # List all files with permissions
cd /var/log             # Change directory
pwd                     # Show current path
mkdir app && cd app     # Create & enter directory
rm -rf tmp/             # Delete directory forcefully
cp file1 file2          # Copy file
mv old new              # Rename / move file
touch app.log           # Create empty file
```

### Permissions & Ownership
```
chmod 755 script.sh     # rwxr-xr-x
chown user:group file   # Change owner
```

### System Information
```
uname -a                # Kernel & OS
hostnamectl             # Host details
free -h                 # Memory usage
df -h                   # Disk usage
uptime                  # Load average
```

### Logs
```
ls /var/log/
journalctl -xe          # System errors
tail -f /var/log/syslog # Follow logs
```

### Services
```
systemctl status nginx
systemctl restart nginx
systemctl enable nginx
systemctl stop nginx
```

## Git Cheat Sheet
### Basic Commands
```
git config                # Configure Git Username & Email
   eg. git config --global user.name "Your Name"
       git config --global user.email "your@email.com"
git init                  # Initialize a Git Repository
git clone repo-url        # Copy a Remote Repository eg.
   git clone https://github.com/user/repo.git
git status                # View Working Directory Status
git log                   # View Commit History
git show <commit-hash>    # Show Details of a Commit
git add .                 # Stage Files for Commit, add all changes
git add file.txt          # add single file change
git commit -m "fix: bug"  # Save Changes to Repo
git diff                  # Compare Changes, unstaged changes
git diff --staged         # staged changes
git tag                   # Create a Tag
   eg. git tag -a v1.0 -m "Version 1.0"
git tag -d v1.0           # Delete a Tag
git push origin --tags    # Push Tags to Remote
git archive --format=zip HEAD > archive.zip  # Create a Zip Archive of Repo
```

### Branching
```
git checkout -b feature/login # Switch Branches
git switch feature-login      # Modern Branch Switch Command
git branch                    # List/Create Branches
git branch feature-login      # create new branch
git merge feature/login       # Merge Branches
```

### Fix Common Issues
```
git stash                  # Save Uncommitted Work
git stash pop              # Restore Stashed Work
git stash list             # View Stashes
git clean –f               # Remove Untracked Files
git reset --hard HEAD~1    # Unstage or Undo Commits
git rebase main            # Reapply Commits
git log --oneline
git cherry-pick <commit-hash> # Apply a Specific Commit
git bisect start           # Find Bug Introduced Commit
git blame file.txt         # Show Line-by-Line Authors
git reflog                 # View All Reference Logs
git submodule              # Manage Submodules
  eg. git submodule add https://github.com/user/repo.git
git gc                     # Garbage Collection, Cleans up unnecessary files and optimizes repo
```

### Remote Repository Commands
```
git remote add origin https://github.com/user/repo.git   # Manage Remote URLs
git push origin main  # Upload Changes to Remote
git push origin HEAD  # Push current branch to origin, without specifying its name
git pull              # Download & Merge Changes
git fetch origin      # Download Changes (No Merge)
git remote -v         # Show Remote URLs
```

### GitHub-Specific (GH CLI)
```
gh auth login         # Login to GitHub
gh repo clone         # Clone Repo from GitHub
gh issue list         # List GitHub Issues
gh pr create          # Create Pull Request
  eg. gh pr create --title "New Feature" --body "Description of the feature"
gh repo create         # Create a New GitHub Repository
  eg. gh repo create my-repo
```

## Networking
### Diagnostics
```
ping google.com
traceroute 8.8.8.8
ip a
ip route
```

### Ports & Connections
```
ss -tulnp
netstat -tulnp
lsof -i :80
```

### DNS
```
dig example.com
nslookup example.com
curl -I https://example.com
```

## Bash Scripting
### Template
```
#!/bin/bash
set -e
for i in {1..5}; do
  echo "Count: $i"
done
```

### Variables & Conditions
```
env="dev"
if [ "$env" == "dev" ]; then
  echo "Development mode"
fi
```

### Useful
```
$?        # Exit code
$0        # Script name
$1        # First argument
```

## Useful Ansible
```
ansible all -m ping -i inventory.txt                   # Ping all servers
ansible webservers -a "uname -a" -i inventory.txt      # Run a command
ansible webservers -m apt -a "name=nginx state=present" -b -i inventory.txt  # Install a package
ansible-playbook -i inventory.txt site.yml             # Run a playbook:
ansible-config dump --only-changed                     # Check configuration
ansible-inventory -i inventory.txt --list              # List inventory
ansible web -a "uptime" -i inventory.txt               # run ad-hoc shell command

# run ad-hoc module
ansible db -m apt -a "name=mariadb-server state=present" -b -i inventory.txt

# run a playbook with vault prompt
ansible-playbook -i inventory.txt site.yml --ask-vault-pass

# run with specific vault password file (safer for CI)
ansible-playbook -i inventory.txt site.yml --vault-password-file ~/.vault_pass.txt

ansible-playbook -i inventory.txt site.yml --check --diff     # dry run / preview
ansible-playbook -i inventory.txt site.yml -vvv               # run with verbosity
```

## Docker
### Common Commands
```
docker build -t app .
docker run -d -p 80:80 app
docker ps
docker logs container
docker exec -it container bash
```

### Troubleshooting
```
docker ps -a
docker inspect container
docker stats
```

### Cleanups
```
docker system prune -a
docker rm $(docker ps -aq)
docker rmi $(docker images -q)
```

## Kubernetes
### Basic Commands
```
kubectl version             # Show client & server versions.
kubectl version --short
kubectl cluster-info        # Show cluster endpoints and basic info.
kubectl cluster-info
kubectl get nodes           # List all cluster nodes.
kubectl get nodes
kubectl get pods            # List pods in the current namespace.
kubectl get pods
kubectl get services        # List services in the current namespace.
kubectl get services
kubectl get namespaces      # List all namespaces.
kubectl get namespaces
kubectl describe pod        # Show detailed information for a pod.
kubectl describe pod my-pod
kubectl logs                # Show logs from a specific pod (container).
kubectl logs my-pod         # single-container pod kubectl logs my-pod -c my-container
kubectl create namespace    # Create a new namespace.
kubectl create namespace my-namespace
kubectl delete pod          # Delete a pod by name.
kubectl delete pod my-pod
```

### Intermediate Commands
```
kubectl apply              # Apply changes from YAML (create/update).
kubectl apply -f deployment.yaml
kubectl delete             # Delete resources defined in YAML.
kubectl delete -f deployment.yaml
kubectl scale              # Scale a deployment to N replicas.
kubectl scale deployment my-deployment --replicas=3
kubectl expose             # Expose a pod/deployment as a Service.
kubectl expose deployment my-deployment --type=LoadBalancer --port=80
kubectl exec               # Execute a command inside a running pod.
kubectl exec -it my-pod -- /bin/bash
kubectl port-forward       # Forward a local port to pod port.
kubectl port-forward pod/my-pod 8080:80
kubectl get configmaps     # List ConfigMaps.
kubectl get configmaps
kubectl get secrets        # List Secrets.
kubectl get secrets
kubectl edit               # Edit a live resource in your editor.
kubectl edit deployment my-deployment
kubectl rollout status     # Check rollout status of a deployment.
kubectl rollout status deployment/my-deployment
```

### Advanced Commands
```
kubectl api-versions      # List API versions supported by the apiserver.
kubectl api-versions
kubectl rollout undo      # Roll back a deployment to a previous revision.
kubectl rollout undo deployment/my-deployment

kubectl top nodes         # Show node resource usage (requires metrics-server).
kubectl top nodes

kubectl top pods          # Show pod resource usage.
kubectl top pods

kubectl cordon            # Mark a node unschedulable (stop new pods scheduling).
kubectl cordon node-name

kubectl uncordon          # Mark a node schedulable again
kubectl uncordon node-name

kubectl drain             # Evict pods safely from a node for maintenance.
kubectl drain node-name --ignore-daemonsets --delete-local-data

kubectl taint             # Add a taint to a node to control scheduling.
kubectl taint nodes node-name key=value:NoSchedule

kubectl get events        # View cluster events (useful for troubleshooting).
kubectl get events --sort-by=.metadata.creationTimestamp

kubectl apply -k          # Apply resources from a Kustomize directory.
kubectl apply -k ./kustomization-dir/

kubectl config view       # Show merged kubeconfig file.
kubectl config view

kubectl config use-context — Switch active context in kubeconfig.
kubectl config use-context my-cluster

kubectl debug             # Start a debugging session for a pod (ephemeral container).
kubectl debug pod/my-pod -it --image=busybox -- /bin/sh

kubectl delete namespace  # Delete a namespace and everything in it.
kubectl delete namespace my-namespace

kubectl patch             # Update a resource using a JSON patch.
kubectl patch deployment my-deployment -p '{"spec": {"replicas": 2}}'

kubectl rollout history   # Show rollout revision history.
kubectl rollout history deployment/my-deployment

kubectl autoscale         # Create HorizontalPodAutoscaler (HPA).
kubectl autoscale deployment my-deployment --cpu-percent=50 --min=1 --max=10

kubectl label             # Add or update labels on a resource.
kubectl label pod my-pod environment=production
kubectl annotate          # Add or update annotations on a resource.

kubectl annotate pod my-pod description="My app pod"
ubectl delete pv          # Delete a PersistentVolume (PV).
kubectl delete pv my-pv

kubectl get ingress       # List Ingress resources.
kubectl get ingress

kubectl create configmap # Create a ConfigMap from literals or files
kubectl create configmap my-config --from-literal=key1=value1
kubectl create configmap my-config --from-file=app.conf

kubectl create secret    # Create a Secret from literals or files.
kubectl create secret generic my-secret --from-literal=password=myPassword
kubectl create secret generic tls-secret --from-file=tls.crt --from-file=tls.key

kubectl api-resources    # List available API resources in the cluster.
kubectl api-resources
```


### Core Commands
```
kubectl get pods
kubectl get svc
kubectl get deploy
kubectl describe pod pod-name
kubectl logs pod-name
kubectl exec -it pod-name -- sh
```

### Apply / Delete
```
kubectl apply -f app.yaml
kubectl delete -f app.yaml
```

### Troubleshooting
```
kubectl get events
kubectl describe node
kubectl rollout status deploy app
kubectl rollout undo deploy app
```

### Common Pod Commands
```
List all Pods (in current namespace)
    kubectl get pod
    kubectl get pods
List Pods with more details (node, IP, etc.)
    kubectl get pod -o wide
Watch Pods in real-time
    kubectl get pod -w
View Pod in YAML format
    kubectl get pod <pod_name> -o yaml
Edit a Pod (live)
    kubectl edit pod <pod_name>
Describe a Pod (events, status, containers)
    kubectl describe pod <pod_name>
Delete a Pod
    kubectl delete pod <pod_name>
View Pod logs
    kubectl logs <pod_name>
Exec into a Pod (get a shell inside the container)
    kubectl exec -it <pod_name> -- /bin/bash
```

### Nodes (Cluster Machines)
```
Get all Nodes
    kubectl get node
    kubectl get nodes
Describe a specific Node
    kubectl describe node <node_name>
View Node as YAML
    kubectl get node <node_name> -o yaml
Cordon a Node (mark unschedulable)
    New Pods will not be scheduled on this node:
    kubectl cordon <node_name>
Uncordon a Node (allow scheduling again)
    kubectl uncordon <node_name>
Drain a Node (safely evict Pods)
    kubectl drain <node_name>
```

### Creating Objects (Pods, Deployments, Services, Configmap, Secret)
**Create from YAML files**
```
Apply a single YAML file
    kubectl apply -f <file_name>.yaml
Apply multiple YAML files
    kubectl apply -f <file1>.yaml -f <file2>.yaml
Apply all YAML files in a directory
    kubectl apply -f ./<directory_name>/
Apply YAML from a URL
    kubectl apply -f https://<url>
```

**Create Pods**
```
Create a Pod directly from an image
    kubectl run <pod_name> --image=<image_name>
Create Pod, expose it as a Service
    kubectl run <pod_name> --image=<image_name> --port=<port> --expose
Generate Pod YAML (without creating it)
    kubectl run <pod_name> --image=<image_name> --dry-run=client -o yaml > pod.yaml
```

**Create Deployments**
```
Create a Deployment
    kubectl create deployment <deployment_name> --image=<image_name>
Generate Deployment YAML
    kubectl create deployment <deployment_name> --image=<image_name> --dry-run=client -o yaml > deployment.yaml
```

**Create Services**
```
Create a Service by type
    kubectl create service <service-type> <service_name> --tcp=<port:target_port>
Example:
    kubectl create service clusterip my-service --tcp=80:8080
Generate Service YAML (without creating it)
    kubectl create service <service-type> <service_name> --tcp=<port:target_port> --dry-run=client -o yaml > service.yaml
Expose an existing Deployment or Pod as a Service
    kubectl expose deployment <deployment_name> --type=<service-type> --port=<port> --target-port=<target_port>
```

**Create ConfigMap**
```
Create ConfigMap from Key-Value Pairs
    kubectl create configmap <configmap_name> --from-literal=<key>=<value> --from-literal=<key>=<value>
Check the ConfigMap
    kubectl get configmap <configmap_name>-o yaml
Create ConfigMap from a File
    kubectl create configmap <configmap_name> --from-file=<file_name>
Check the ConfigMap
    kubectl describe configmap <configmap_name>
Create ConfigMap from Environment File (.env)
    kubectl create configmap <configmap_name> --from-env-file=<file_name>
```

**Create Secret**
```
A Secret is like ConfigMap but made for sensitive data, such as passwords, tokens, API keys etc.
Kubernetes stores them base64-encoded (not encrypted by default).
Create Secret from Key-Value Pairs
    kubectl create secret generic <secret_name> --from-literal=<key>=<value> --from-literal=<key>=<value>
Create ConfigMap from a File
    kubectl create secret generic <secret_name> --from-file=<file_name>
```

**Monitoring Usage**
```
CPU and memory usage for Nodes
    kubectl top node
CPU and memory usage for Pods
    kubectl top pod # or kubectl top pods
```

**Deployment Commands**
```
Deployments manage ReplicaSets and Pods for you.
Get Deployments
    kubectl get deployment or kubectl get deployment <deployment_name>
Get Deployment in YAML
    kubectl get deployment <deployment_name> -o yaml
Get Deployment with wide info
    kubectl get deployment <deployment_name> -o wide
Edit a Deployment
    kubectl edit deployment <deployment_name>
Describe a Deployment
    kubectl describe deployment <deployment_name>
Delete a Deployment
    kubectl delete deployment <deployment_name>
Scale a Deployment
    kubectl scale deployment <deployment_name> --replicas=<number>
```


### Service, Ingress, DaemonSet, Job, Secret, Endpoints.
**Service**
```
Get:
    kubectl get service or kubectl get service <service_name>
YAML:
    kubectl get service <service_name> -o yaml
Wide info
    kubectl get service <service_name> -o wide
Describe:
    kubectl describe service <service_name>
Edit:
    kubectl edit service <service_name>
Delete:
    kubectl delete service <service_name>
```

**Ingress**
```
Get:
    kubectl get ingress
YAML:
    kubectl get ingress <ingress_name> -o yaml
Describe:
    kubectl describe ingress <ingress_name>
Wide info
    kubectl get ingress <service_name> -o wide
Edit:
    kubectl edit ingress <ingress_name>
Delete:
    kubectl delete ingress <ingress_name>
```

**DaemonSet**
```
Get:
    kubectl get daemonset kubectl get daemonset <daemonset_name>
YAML:
    kubectl get daemonset <daemonset_name> -o yaml
Describe:
    kubectl describe daemonset <daemonset_name>
Edit:
    kubectl edit daemonset <daemonset_name>
Delete:
    kubectl delete daemonset <daemonset_name>
```

**Job**
```
Get:
    kubectl get job kubectl get job <job_name>
YAML:
    kubectl get job <job_name> -o yaml
Describe:
    kubectl describe job <job_name>
Edit:
    kubectl edit job <job_name>
Delete:
    kubectl delete job <job_name>
```

**Secret**
```
Get:
    kubectl get secret kubectl get secret <secret_name>
Describe:
    kubectl describe secret <secret_name>
Edit:
    kubectl edit secret <secret_name>
Delete:
    kubectl delete secret <secret_name>
View Secret in base64 format:
    kubectl get secret <secret_name> -o yaml
Decode it:
echo "<base64" | base64 --decode
```

**Endpoints**
```
Get endpoints
    kubectl get endpoints <endpoints_name>
```

**Rollout & Version History**
```
Useful when you deploy new versions and something goes wrong.
Restart a Deployment
    kubectl rollout restart deployment <deployment_name>
View rollout history
    kubectl rollout history deployment <deployment_name>
View specific revision
    kubectl rollout history deployment <deployment_name> --revision=<revision_number>
Undo to previous revision
    kubectl rollout undo deployment <deployment_name>
Undo to specific revision
    kubectl rollout undo deployment <deployment_name> --to-revision=<revision_number>
```

**Deploy and Expose an NGINX Application**
```
kubectl run nginx-pod --image=nginx
```

**Create a Deployment**
```
kubectl create deployment nginx-deployment --image=nginx:latest
```

**Scale the Deployment**
```
kubectl scale deployment nginx-deployment --image=nginx --replicas=3
```

**Expose the Deployment as a Service**
```
kubectl expose deployment nginx-deployment \
  --type=NodePort \
  --port=80 --target-port=80
```

**Debug a Failing Pod**
```
List Pods and Check Status
    kubectl get pod
Describe the Pod
    kubectl describe pod api-pod-demo-zxy
Check Pod Logs
    kubectl logs api-pod-demo-zxy
    kubectl logs api-pod-demo-zxy -c <container_name>
Edit the Deployment or Pod Spec
If the Pod is part of a Deployment:
    kubectl edit deployment api-deployment
Confirm Fix
    kubectl get pod
    kubectl describe pod <new_pod_name>
    kubectl logs <new_pod_name>
```

**Using Secret inside a Pod**
```
apiVersion: v1
kind: Pod
metadata:
  name: secret-demo
spec:
  containers:
  - name: app
    image: nginx
    env:
      - name: USER_NAME
        valueFrom:
          secretKeyRef:
            name: my-secret
            key: username
      - name: USER_PASS
        valueFrom:
          secretKeyRef:
            name: my-secret
            key: password
```


**Using ConfigMap inside a Pod**
```
Pod YAML sample:
apiVersion: v1
kind: Pod
metadata:
  name: configmap-demo
spec:
  containers:
  - name: app
    image: nginx
    envFrom:
    - configMapRef:
        name: my-config
```

**Quick Fix**
```
Use kubectl get <resource> -o yaml to see the full configuration of any resource.
Use kubectl edit <resource> <name> for quick inline edits when you know what to fix.
Use kubectl rollout history and kubectl rollout undo when experimenting with new versions in production.
```

## HELM
### BASIC COMMANDS
```
helm help               # Show help info
helm install --help
helm version            # Check client/server version
helm repo add           # Add a chart repository
  eg. helm repo add stable https://charts.helm.sh/stable
helm repo update        # Refresh repositories
helm repo list          # Show added repos
helm search hub         # Search charts on Helm Hub
  eg. helm search hub nginx
helm search repo        # Search local repos
  eg. helm search repo mongodb
```

## MySQL
### BASIC COMMANDS
```
SELECT VERSION();                    # Check MySQL Version
SELECT DATABASE();                   # Show current database
SELECT user, host FROM mysql.user;   # List all users
DESC tablet_demo;                    # Describe table structure
SELECT * FROM information_schema.TABLE_CONSTRAINTS LIMIT 50;  # Check constraints

Query Examples:
SELECT MAX(balance) FROM accounts;
ELECT * FROM accounts LIMIT 5;
```

## YAML
### Structure Reference
```
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: nginx
    ports:
    - containerPort: 80
```

## Terraform
### Core Commands
```
terraform init
terraform plan
terraform apply
terraform destroy
```

### State Management
```
terraform state list
terraform import aws_instance.web i-123
terraform refresh
```

### Structure
```
provider "aws" {}
resource "aws_instance" "web" {
  ami           = "ami-123"
  instance_type = "t2.micro"
}
```

## CI/CD
### Pipeline Stages
```
Build → Test → Scan → Deploy → Notify
```

**Jenkinsfile Template**
```
pipeline {
  stages {
    stage('Build') {
      steps {
        sh 'npm install'
      }
    }
  }
}
```

## AWS
### EC2
ssh -i key.pem ubuntu@ip
systemctl status app
df -h

### S3
```
aws s3 ls
aws s3 cp file s3://bucket
aws s3 sync ./data s3://bucket
```

### CloudWatch
```
aws logs describe-log-groups
aws logs tail /aws/lambda/app --follow
```

### IAM Best Practices
```
Least privilege
MFA enabled
No root usage
Rotate keys
```

### Monitoring & Logging
**Prometheus**
- Exporters
- Metrics scraping
- Alert rules
  
**Grafana**
- Dashboards
- Data sources
- Alerts

## DevSecOps Security Tools
```
trivy image app
snyk test
```
- Compliance (PCI-DSS, SOC2, ISO)

## DevOps Best Practices
- Automate everything
- Infrastructure as Code
- Shift-left security
- Monitoring from day one
- Stateless applications
- Document incident fixes
- Use version control for everything

## The End

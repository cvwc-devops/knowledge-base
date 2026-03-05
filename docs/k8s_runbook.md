# Kubernetes Production Runbooks

### Golden Signals–Aligned

🚨 DeploymentUnavailable

Severity: Critical
Golden Signal: Errors
Pages On: PagerDuty

**Description**

The deployment has zero available replicas. The service is fully unavailable.

**Impact**

All user traffic is failing

Hard outage

**Immediate Actions**

1. Identify recent deployments:

kubectl rollout history deployment <name>


2. Roll back immediately:

kubectl rollout undo deployment <name>

**Investigate**

Pod events (kubectl describe pod)

Image pull errors

ConfigMap / Secret changes

**Resolution**

Restore previous healthy version

Verify replicas become Ready

**Escalate If**

Rollback fails

No pods become Ready within 5 minutes

🚨 HighErrorRate

Severity: Critical
Golden Signal: Errors
Pages On: PagerDuty

**Description**

More than 5% of requests are returning 5xx errors.

**Impact**

Users experiencing failures

Likely SLO breach

**Immediate Actions**

Check recent deployments

Inspect application logs

Identify failing endpoints

**Mitigation**

Roll back latest deploy

Restart unhealthy pods

Disable failing feature flags

**Verify**

Error rate returns to baseline

Latency stabilizes

🚨 NoSuccessfulRequests

Severity: Critical
Golden Signal: Errors / Traffic
Pages On: PagerDuty

**Description**

Traffic exists, but no requests are succeeding.

**Impact**

Silent total outage

**Immediate Actions**

Check ingress rules

Verify Service endpoints

Confirm pods are Ready

**Mitigation**

Restart ingress controller

Fix service selectors

Roll back misconfiguration

🚨 HighRequestLatency (p95 / p99)

Severity: Critical
Golden Signal: Latency
Pages On: PagerDuty

**Description**

User request latency exceeds acceptable thresholds.

**Impact**

Severe user experience degradation

**Immediate Actions**

Check error rate

Check saturation (CPU, memory)

Identify recent deploys

**Mitigation**

Scale replicas

Roll back recent deploy

Fail over dependencies if possible

🚨 TrafficDrop

Severity: Critical
Golden Signal: Traffic
Pages On: PagerDuty

**Description**

Request rate dropped below expected baseline.

**Impact**

Users may be unable to reach the service

**Immediate Actions**

Check DNS resolution

Check ingress controller health

Verify load balancer status

**Mitigation**

Restore routing

Restart ingress

Fail over DNS if configured

🚨 IngressHigh5xx

Severity: Critical
Golden Signal: Errors
Pages On: PagerDuty

**Description**

Ingress is returning high rates of 5xx errors.

**Impact**

Multiple services may be affected

**Immediate Actions**

Check backend service health

Review recent ingress changes

**Mitigation**

Roll back ingress config

Restart ingress controller pods

🚨 WidespreadCrashLooping

Severity: Critical
Golden Signal: Errors
Pages On: PagerDuty

**Description**

Large number of pods restarting in a short time window.

**Impact**

Likely bad deployment or shared dependency failure

**Immediate Actions**

Identify common image/config

Check recent cluster-wide changes

**Mitigation**

Roll back affected deployments

Restore last known good config

🚨 ImagePullFailures

Severity: Critical
Golden Signal: Errors
Pages On: PagerDuty

**Description**

Pods cannot pull container images.

**Impact**

Deployments blocked

Services may never start

**Immediate Actions**

Verify image tag exists

Check registry credentials

**Mitigation**

Fix image reference

Restore registry access

Roll back deployment

🚨 NodeDiskFull

Severity: Critical
Golden Signal: Saturation
Pages On: PagerDuty

**Description**

Node disk space below safe threshold.

**Impact**

Pod evictions

Scheduling failures

**Immediate Actions**

Identify affected node

Check disk usage (logs, images)

**Mitigation**

Clean logs

Prune images

Replace node if necessary

🚨 NodeMemoryPressure

Severity: Critical
Golden Signal: Saturation
Pages On: PagerDuty

**Description**

Node is under memory pressure.

**Impact**

OOM kills

Pod instability

**Immediate Actions**

Identify top memory consumers

Check recent traffic spikes

**Mitigation**

Scale workloads

Increase memory limits

Replace node if needed

🚨 HPAMaxedAndErrors

Severity: Critical
Golden Signal: Saturation + Errors
Pages On: PagerDuty

**Description**

HPA is at max replicas and errors are occurring.

**Impact**

System cannot scale further

User failures likely

**Immediate Actions** 

Increase HPA max replicas

Add cluster capacity

**Mitigation**

Scale node pool

Reduce incoming traffic if possible

🚨 KubeAPIDown

Severity: Critical
Golden Signal: Errors
Pages On: PagerDuty

**Description**

Kubernetes API server is unreachable.

**Impact**

Cluster management unavailable

Deployments blocked

**Immediate Actions**

Check cloud provider status

Verify control-plane nodes

**Mitigation**

Restart API server (self-managed)

Contact cloud provider support

🚨 MultipleNodesNotReady

Severity: Critical
Golden Signal: Saturation
Pages On: PagerDuty

**Description**

Multiple nodes are NotReady.

**Impact**

Reduced cluster capacity

Scheduling failures

**Immediate Actions**

Check node events

Review cloud or network incidents

**Mitigation**

Replace nodes

Restore networking

Scale node pool

🚨 PodsUnschedulable

Severity: Critical
Golden Signal: Saturation
Pages On: PagerDuty

**Description**

Pods cannot be scheduled for extended time.

**Impact**

New workloads cannot start

**Immediate Actions**

Check node capacity

Review taints and tolerations

**Mitigation**

Add nodes

Adjust resource requests

🚨 DeploymentRolloutStuck

Severity: Critical
Golden Signal: Errors
Pages On: PagerDuty

**Description**

Deployment rollout is not progressing.

**Impact**

New version not fully running

Partial outage possible

**Immediate Actions**

Check rollout status

Inspect pod events

**Mitigation**

Roll back deployment

Fix image or config issues

🚨 ErrorSpikeAfterDeploy

Severity: Critical
Golden Signal: Errors
Pages On: PagerDuty

**Description**

Error rate increased significantly after deployment.

**Impact**

Regression introduced

**Immediate Actions**

Roll back deployment immediately

**Verify**

Error rate returns to baseline

**🧭 Operator Rule (Pin This)**

If you can’t confidently fix the issue in 10 minutes, roll back first. Investigate after recovery.

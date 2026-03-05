

Ask These 5 Questions (in order)

1. Is it user-facing?
    * External customers?
    * Internal users only?
    * Background jobs?
3. How many services are affected?
    * One service?
    * A dependency chain?
    * Everything behind ingress?
4. How many environments?
    * Prod only?
    * Multiple clusters?
    * One region or all regions?
5. How much traffic is impacted?
    * 1 pod?
    * 1 deployment?
    * Entire node pool?
6. Is the impact growing or contained?
    * Stable
    * Degrading
    * Cascading


🚨 Production Incident Flow (One Page)

Scope: Kubernetes + Linux
Audience: Primary & Secondary On-Call
Goal: Restore service fast, escalate correctly

1️⃣ PagerDuty Fires (0–2 min)

☑ Acknowledge immediately
☑ Post in incident channel:

Ack’d. Investigating.


If you can’t act now → reassign or escalate.

2️⃣ Confirm Impact (2–5 min)

Ask:

User-facing or internal?

One service or many?

Recent deploy?

Quick check:

* kubectl get nodes
* kubectl get pods -A | grep -E 'Crash|Error|Pending'

3️⃣ Decide the Path (Critical Decision)
Signal	Go Here
CrashLoop / rollout / errors	Kubernetes
Pods Pending / Node NotReady	Linux
Widespread failures	Kubernetes → Linux

Rule: Kubernetes first. SSH only if K8s points you there.

4️⃣ Kubernetes Path (Fast Fixes)
Deployments / Pods
* kubectl describe pod <pod>
* kubectl logs <pod> --previous
* kubectl rollout undo deployment <name>


✔ Roll back before debugging
❌ No shelling into pods during outages

Latency / Errors
* kubectl top pods
* kubectl get hpa


✔ Scale replicas
✔ Increase HPA max
✔ Roll back recent deploy

Ingress / Traffic
* kubectl get pods -n ingress-nginx
* kubectl logs -n ingress-nginx <pod>


✔ Restart ingress
✔ Roll back ingress config
✔ Fail over DNS if available

5️⃣ Linux Path (Only When Needed)
Node NotReady / Unreachable
* kubectl describe node <node>


If SSH works:

* uptime
* journalctl -xb


✔ Replace node if recovery >10 min

* CPU / Memory / Disk
* top
* free -h
* df -h


✔ Restart offender
✔ Clean safely
✔ Replace node if unstable

Rule: A replaced node is better than a sick node.

6️⃣ Reboot / Replace Decision
* Condition	Action
* Kernel panic	Reboot
* Hung I/O	Reboot
* Disk full	Clean / Replace
* Repeated OOM	Replace
* Unknown + unstable	Replace
7️⃣ Escalate (≤15 min)

Escalate if:

Still broken after 15 min

Multiple nodes/services impacted

Control plane involved

You’re unsure

Targets:

Secondary on-call

Platform / Infra

Cloud provider

8️⃣ Verify Recovery

Must be true:

Error rate normal

Latency stable

Pods Ready

Nodes Ready

* kubectl get nodes
* kubectl get pods -A

9️⃣ Resolve & Communicate

PagerDuty:

Resolve incident

Slack:

Resolved. Service stable. RCA to follow.

🔒 On-Call Rules (Memorize These)

Restore service first

* Rollback beats debugging

* Replace nodes without guilt

Escalate after 15 minutes

* Document everything

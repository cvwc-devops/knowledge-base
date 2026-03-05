# Linux Production Runbook
A practical guide for on-call Linux incidents

### 0. Before You Touch Anything (Golden Rules)
 1. Confirm impact
* What is broken?
* Who is affected?
* Is it user-facing?

2. Stabilize first
* Restore service availability
* Then investigate root cause

3. Change as little as possible
* Avoid “exploratory fixes”
* Prefer reversible actions

4. Document actions
* Commands run
* Files changed
* Time of change

## 1. Host Unreachable / SSH Fails
**Symptoms**
* SSH timeout
* Monitoring reports host down
* Node marked NotReady (Kubernetes)

**Immediate Checks**

* ping host
* nc -zv host 22

**If Using Cloud**

Check cloud console:
* Instance running?
* Network interface attached?
* Security group / firewall rules?
* Check provider incident status

**If Console Access Available**

* uptime
* dmesg | tail
* journalctl -xb

**Common Causes**

* Kernel panic
* Disk full
* Network interface down
* OOM storm

**Mitigation**
* Reboot if unresponsive
* Replace node if recovery >10 minutes

## 2. High Load Average / CPU Saturation
**Symptoms**

* High load
* Slow commands
* Latency alerts

**Diagnose**

* uptime
* top
* htop
* mpstat -P ALL 1

**Identify Culprit**

* ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%cpu | head

**Mitigation**

* Restart runaway process
* Scale service (preferred)
* Throttle or kill process (last resort)

* kill -TERM <pid>
* kill -KILL <pid>   # only if necessary

## 3. Memory Pressure / OOM Kills
**Symptoms**
* Processes killed
* NodeMemoryPressure
* Kernel OOM logs

**Diagnose**

* free -h
* vmstat 1
* dmesg | grep -i oom
* journalctl -k | grep -i oom

**Find Memory Hogs**

* ps aux --sort=-%mem | head

**Mitigation**
* Restart offending process
* Increase memory limits
* Add swap (temporary mitigation only)
* Replace node if persistent

## 4. Disk Full / Disk Pressure
**Symptoms**
* Writes failing
* Pods evicted
* No space left on device

**Diagnose**

* df -h
* df -i

**Find Large Files**

* du -xh / | sort -h | tail

**Common Culprits**
* Logs
* Docker/container images
* Temp files

**Mitigation**

* journalctl --vacuum-time=2d
* docker system prune -af
* rm -rf /tmp/*

⚠️ Never delete blindly on production disks

## 5. Network Issues
**Symptoms**
* Packet loss
* Cannot reach dependencies
* Intermittent failures

**Diagnose**

* ip addr
* ip route
* ss -tulnp
* ping <gateway>
* traceroute <destination>

**DNS Checks**

* cat /etc/resolv.conf
* dig example.com

**Mitigation**
* Restart network service (last resort)
* Fail over traffic
* Replace node if network unstable

## 6. Time Skew / Clock Drift
**Symptoms**
* TLS errors
* Authentication failures
* Distributed system instability

**Diagnose**
* timedatectl
* chronyc tracking

**Fix**

* timedatectl set-ntp true
* systemctl restart chronyd

## 7. File Descriptor Exhaustion
**Symptoms**
* “Too many open files”
* Services failing under load

**Diagnose**

* ulimit -n
* cat /proc/sys/fs/file-max
* lsof | wc -l

**Mitigation**

* Restart leaking process
* Increase limits cautiously
* Fix application leak


## 8. Zombie / Hung Processes
**Diagnose**

* ps aux | grep Z
* ps -eo pid,stat,cmd | grep D

**Mitigation**

* Restart parent process
* Reboot node if unkillable

## 9. Kernel / System Issues
**Symptoms**
* Kernel warnings
* Soft lockups
* Random freezes

**Diagnose**

* dmesg -T | tail
* journalctl -k

**Mitigation**

* Reboot node
* Replace node if recurring
* Escalate to platform/kernel team

## 10. Safe Restart Checklist
**Before restarting anything:**

* Confirm HA / replicas exist
* Drain traffic if possible
* Announce in incident channel
* systemctl restart <service>

**After restart:**

* Verify service health
* Monitor for regression

## 11. Reboot Decision Matrix
** Situation.............,,Reboot?
* Kernel panic..........,,✅ Immediately
* Disk full.............,,❌ Fix first
* OOM storm.............,,⚠️ After mitigation
* Hung I/O..............,,✅ Often required
* Intermittent issue....,,❌ Investigate

## 12. Post-Incident Actions (Mandatory)
**After recovery:**
* Capture timeline
* Save logs
* Identify root cause
* Create follow-up task
* Update monitoring/runbooks

## 13. Emergency Commands Cheat Sheet

* uptime
* top
* free -h
* df -h
* journalctl -xe
* dmesg | tail
* ss -tulnp

* ps aux --sort=-%cpu | head

📌 Operator Rule (Pin This)

* Restore service first. Root cause second. Documentation always.

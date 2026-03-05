#!/bin/bash

# Production Kubernetes Homelab - Verification Script
# This script verifies the health and connectivity of your Kubernetes cluster
# Exit codes: 0 = success, 1 = cluster issues, 2 = namespace issues, 3 = pod issues, 4 = service issues

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="humor-game"
MONITORING_NAMESPACE="monitoring"
ARGOCD_NAMESPACE="argocd"
INGRESS_NAMESPACE="ingress-nginx"

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO") echo -e "${BLUE}ℹ️  INFO:${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}✅ SUCCESS:${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}⚠️  WARNING:${NC} $message" ;;
        "ERROR") echo -e "${RED}❌ ERROR:${NC} $message" ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check exit code and print result
check_exit() {
    local exit_code=$1
    local success_msg=$2
    local error_msg=$3
    if [ $exit_code -eq 0 ]; then
        print_status "SUCCESS" "$success_msg"
        return 0
    else
        print_status "ERROR" "$error_msg"
        return 1
    fi
}

# Header
echo "🔍 Production Kubernetes Homelab - Verification Script"
echo "=================================================="
echo ""

# Check prerequisites
print_status "INFO" "Checking prerequisites..."

if ! command_exists kubectl; then
    print_status "ERROR" "kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command_exists k3d; then
    print_status "ERROR" "k3d not found. Please install k3d first."
    exit 1
fi

print_status "SUCCESS" "Prerequisites check passed"
echo ""

# Check cluster status
print_status "INFO" "Checking cluster status..."

# Check if k3d cluster exists
if ! k3d cluster list | grep -q "homelab"; then
    print_status "ERROR" "k3d cluster 'homelab' not found. Please create it first."
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_status "ERROR" "Cannot connect to Kubernetes cluster. Check if cluster is running."
    exit 1
fi

# Check cluster nodes
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
if [ "$NODE_COUNT" -eq 0 ]; then
    print_status "ERROR" "No nodes found in cluster"
    exit 1
fi

print_status "SUCCESS" "Cluster is accessible with $NODE_COUNT node(s)"
echo ""

# Check namespaces
print_status "INFO" "Checking namespaces..."

# Check if required namespaces exist
MISSING_NAMESPACES=()
for ns in "$NAMESPACE" "$MONITORING_NAMESPACE" "$ARGOCD_NAMESPACE" "$INGRESS_NAMESPACE"; do
    if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
        MISSING_NAMESPACES+=("$ns")
    fi
done

if [ ${#MISSING_NAMESPACES[@]} -gt 0 ]; then
    print_status "ERROR" "Missing namespaces: ${MISSING_NAMESPACES[*]}"
    exit 2
fi

print_status "SUCCESS" "All required namespaces exist"
echo ""

# Check pods in humor-game namespace
print_status "INFO" "Checking pods in $NAMESPACE namespace..."

POD_COUNT=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
if [ "$POD_COUNT" -eq 0 ]; then
    print_status "ERROR" "No pods found in $NAMESPACE namespace"
    exit 3
fi

# Check pod readiness
READY_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers | grep -c "Running\|Completed")
TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)

if [ "$READY_PODS" -ne "$TOTAL_PODS" ]; then
    print_status "WARNING" "Not all pods are ready: $READY_PODS/$TOTAL_PODS"
    
    # Show pod status
    echo ""
    echo "Pod Status:"
    kubectl get pods -n "$NAMESPACE" -o wide
    
    # Show any failed pods
    FAILED_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers | grep -E "(Error|CrashLoopBackOff|Pending|Failed)")
    if [ -n "$FAILED_PODS" ]; then
        echo ""
        echo "Failed Pods:"
        echo "$FAILED_PODS"
    fi
    
    exit 3
fi

print_status "SUCCESS" "All $TOTAL_PODS pods in $NAMESPACE namespace are ready"
echo ""

# Check monitoring namespace pods
print_status "INFO" "Checking monitoring namespace pods..."

MONITORING_PODS=$(kubectl get pods -n "$MONITORING_NAMESPACE" --no-headers | wc -l)
if [ "$MONITORING_PODS" -gt 0 ]; then
    READY_MONITORING=$(kubectl get pods -n "$MONITORING_NAMESPACE" --no-headers | grep -c "Running")
    TOTAL_MONITORING=$(kubectl get pods -n "$MONITORING_NAMESPACE" --no-headers | wc -l)
    
    if [ "$READY_MONITORING" -eq "$TOTAL_MONITORING" ]; then
        print_status "SUCCESS" "All $TOTAL_MONITORING monitoring pods are ready"
    else
        print_status "WARNING" "Monitoring pods not fully ready: $READY_MONITORING/$TOTAL_MONITORING"
    fi
else
    print_status "WARNING" "No monitoring pods found (optional for basic setup)"
fi
echo ""

# Check services
print_status "INFO" "Checking services..."

# Check if services exist
SERVICES=("humor-game-frontend" "humor-game-backend" "humor-game-postgres" "humor-game-redis")
MISSING_SERVICES=()

for svc in "${SERVICES[@]}"; do
    if ! kubectl get service "$svc" -n "$NAMESPACE" >/dev/null 2>&1; then
        MISSING_SERVICES+=("$svc")
    fi
done

if [ ${#MISSING_SERVICES[@]} -gt 0 ]; then
    print_status "ERROR" "Missing services: ${MISSING_SERVICES[*]}"
    exit 4
fi

print_status "SUCCESS" "All required services exist"
echo ""

# Check ingress
print_status "INFO" "Checking ingress configuration..."

if ! kubectl get ingress -n "$NAMESPACE" >/dev/null 2>&1; then
    print_status "WARNING" "No ingress found in $NAMESPACE namespace (optional for local development)"
else
    INGRESS_COUNT=$(kubectl get ingress -n "$NAMESPACE" --no-headers | wc -l)
    print_status "SUCCESS" "Found $INGRESS_COUNT ingress resource(s)"
fi
echo ""

# Check service reachability
print_status "INFO" "Checking service reachability..."

# Test backend service
if kubectl port-forward -n "$NAMESPACE" service/humor-game-backend 3001:3001 >/dev/null 2>&1 &; then
    BACKEND_PID=$!
    sleep 2
    
    if curl -s http://localhost:3001/health >/dev/null 2>&1; then
        print_status "SUCCESS" "Backend service is reachable"
    else
        print_status "ERROR" "Backend service health check failed"
        kill $BACKEND_PID 2>/dev/null || true
        exit 4
    fi
    
    kill $BACKEND_PID 2>/dev/null || true
else
    print_status "WARNING" "Could not test backend service connectivity"
fi

# Test frontend service
if kubectl port-forward -n "$NAMESPACE" service/humor-game-frontend 8080:80 >/dev/null 2>&1 &; then
    FRONTEND_PID=$!
    sleep 2
    
    if curl -s http://localhost:8080 >/dev/null 2>&1; then
        print_status "SUCCESS" "Frontend service is reachable"
    else
        print_status "ERROR" "Frontend service is not responding"
        kill $FRONTEND_PID 2>/dev/null || true
        exit 4
    fi
    
    kill $FRONTEND_PID 2>/dev/null || true
else
    print_status "WARNING" "Could not test frontend service connectivity"
fi

echo ""

# Check resource usage
print_status "INFO" "Checking resource usage..."

# Check node resources
NODE_MEMORY=$(kubectl top nodes --no-headers 2>/dev/null | awk '{print $4}' | head -1 || echo "N/A")
NODE_CPU=$(kubectl top nodes --no-headers 2>/dev/null | awk '{print $2}' | head -1 || echo "N/A")

if [ "$NODE_MEMORY" != "N/A" ] && [ "$NODE_CPU" != "N/A" ]; then
    print_status "INFO" "Node resource usage - CPU: $NODE_CPU, Memory: $NODE_MEMORY"
else
    print_status "WARNING" "Could not retrieve resource usage (metrics-server may not be running)"
fi

# Check pod resources
POD_RESOURCES=$(kubectl top pods -n "$NAMESPACE" --no-headers 2>/dev/null || echo "N/A")
if [ "$POD_RESOURCES" != "N/A" ]; then
    print_status "INFO" "Pod resource usage available"
else
    print_status "WARNING" "Could not retrieve pod resource usage"
fi

echo ""

# Final status
print_status "SUCCESS" "Verification completed successfully!"
echo ""
echo "🎉 Your Kubernetes homelab is healthy and ready!"
echo ""
echo "📊 Summary:"
echo "   • Cluster: ✅ Accessible"
echo "   • Namespaces: ✅ All required namespaces exist"
echo "   • Pods: ✅ $READY_PODS/$TOTAL_PODS ready in $NAMESPACE"
echo "   • Services: ✅ All required services exist"
echo "   • Connectivity: ✅ Services are reachable"
echo ""
echo "🚀 Next steps:"
echo "   • Access your application: http://localhost:8080"
echo "   • Check monitoring: kubectl port-forward -n monitoring service/grafana 3000:3000"
echo "   • View logs: kubectl logs -n $NAMESPACE -l app=humor-game-backend"
echo ""

exit 0

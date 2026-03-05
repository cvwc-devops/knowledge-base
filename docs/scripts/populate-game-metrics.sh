#!/bin/bash

echo "🎮 Populating Game Metrics for Dashboard..."

BACKEND_URL="http://localhost:3001"

echo "📊 Testing backend at: $BACKEND_URL"

# Generate health checks
echo "🔄 Generating health check requests..."
for i in {1..50}; do
    curl -s "$BACKEND_URL/health" > /dev/null
    echo -n "."
    sleep 0.1
done
echo ""

# Generate API requests
echo "🔄 Generating API requests..."
for i in {1..20}; do
    curl -s "$BACKEND_URL/api" > /dev/null
    curl -s "$BACKEND_URL/api/health" > /dev/null
    echo -n "."
    sleep 0.2
done
echo ""

# Simulate some user interactions that would generate game metrics
echo "🎯 Simulating game interactions..."
for i in {1..10}; do
    # These endpoints might not exist but will generate HTTP metrics
    curl -s "$BACKEND_URL/api/game/start" > /dev/null
    curl -s "$BACKEND_URL/api/game/match" > /dev/null
    curl -s "$BACKEND_URL/api/scores" > /dev/null
    curl -s "$BACKEND_URL/api/leaderboard" > /dev/null
    echo -n "."
    sleep 0.3
done
echo ""

# Generate some errors for error tracking
echo "⚠️ Generating sample errors..."
for i in {1..8}; do
    curl -s "$BACKEND_URL/api/nonexistent$i" > /dev/null
    curl -s "$BACKEND_URL/missing-endpoint" > /dev/null
    echo -n "."
    sleep 0.2
done
echo ""

echo "📈 Checking available metrics..."
echo "HTTP Requests:"
curl -s 'http://localhost:9090/api/v1/query?query=http_requests_total' | jq '.data.result | length' 2>/dev/null || echo "Metric not ready yet"

echo "Active Games:"
curl -s 'http://localhost:9090/api/v1/query?query=active_games_current' | jq '.data.result[0].value[1]' 2>/dev/null || echo "Metric not ready yet"

echo "App Health:"
curl -s 'http://localhost:9090/api/v1/query?query=app_health_status' | jq '.data.result[0].value[1]' 2>/dev/null || echo "Metric not ready yet"

echo ""
echo "✅ Metrics population complete!"
echo "📊 Check your Grafana dashboard at: http://localhost:3000"
echo "🔍 Refresh the dashboard and metrics should appear within 30 seconds"
echo ""
echo "💡 Available working metrics:"
echo "  • http_requests_total"
echo "  • http_errors_total"
echo "  • http_request_duration_seconds"
echo "  • app_health_status"
echo "  • app_memory_usage_bytes"
echo "  • app_cpu_usage_percent"
echo "  • database_connections_current"

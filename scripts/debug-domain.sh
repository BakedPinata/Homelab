#!/bin/bash
# debug-domain.sh - Debug domain and Cloudflare issues

DOMAIN=${1:-$DOMAIN}
if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain>"
    echo "Or set DOMAIN environment variable"
    exit 1
fi

echo "=== Debugging domain: $DOMAIN ==="
echo ""

# Check DNS resolution
echo "1. DNS Resolution:"
echo "-------------------"
echo "Checking portainer.$DOMAIN:"
nslookup portainer.$DOMAIN
echo ""
echo "Checking your external IP:"
curl -s ifconfig.me
echo ""
echo ""

# Check if ports are accessible
echo "2. Port Accessibility:"
echo "----------------------"
echo "Testing port 80:"
nc -zv $DOMAIN 80 2>&1 | grep -v "^$"
echo "Testing port 443:"
nc -zv $DOMAIN 443 2>&1 | grep -v "^$"
echo ""

# Check Traefik configuration
echo "3. Traefik Status:"
echo "------------------"
if curl -s http://localhost:8080/api/overview > /dev/null 2>&1; then
    echo "✅ Traefik dashboard accessible"
    
    echo ""
    echo "HTTP Routers:"
    curl -s http://localhost:8080/api/http/routers | jq -r '.[] | "\(.name): \(.rule) -> \(.service)"' 2>/dev/null || echo "Failed to get routers"
    
    echo ""
    echo "Certificates:"
    curl -s http://localhost:8080/api/http/routers | jq -r '.[] | select(.tls.certResolver) | "\(.name): \(.tls.certResolver)"' 2>/dev/null || echo "Failed to get certificates"
else
    echo "❌ Traefik dashboard not accessible"
fi
echo ""

# Check Docker labels
echo "4. Docker Service Labels:"
echo "-------------------------"
for container in $(docker ps --format "{{.Names}}"); do
    labels=$(docker inspect $container | jq -r '.[0].Config.Labels | to_entries[] | select(.key | startswith("traefik.")) | "\(.key)=\(.value)"' 2>/dev/null)
    if [ ! -z "$labels" ]; then
        echo "Container: $container"
        echo "$labels" | head -5
        echo ""
    fi
done

# Check Cloudflare API Token
echo "5. Cloudflare API Test:"
echo "-----------------------"
if [ ! -z "$CLOUDFLARE_API_TOKEN" ]; then
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
         -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
         -H "Content-Type: application/json")
    
    if echo "$response" | grep -q '"success":true'; then
        echo "✅ Cloudflare API token is valid"
    else
        echo "❌ Cloudflare API token is invalid or expired"
        echo "Response: $response"
    fi
else
    echo "⚠️  CLOUDFLARE_API_TOKEN not set"
fi
echo ""

# Check Traefik logs for errors
echo "6. Recent Traefik Errors:"
echo "------------------------"
docker logs traefik 2>&1 | grep -E "ERR|error" | tail -5
echo ""

# Test with curl
echo "7. HTTP/HTTPS Response Test:"
echo "----------------------------"
echo "Testing HTTP redirect:"
curl -I -L --max-redirs 0 http://portainer.$DOMAIN 2>/dev/null | head -3

echo ""
echo "Testing HTTPS:"
curl -I https://portainer.$DOMAIN 2>/dev/null | head -3

echo ""
echo "Testing with Host header locally:"
curl -H "Host: portainer.$DOMAIN" http://localhost 2>/dev/null | head -3

echo ""
echo "=== Suggestions ==="
echo ""
if ! nc -zv $DOMAIN 443 2>&1 | grep -q succeeded; then
    echo "❌ Port 443 is not accessible from outside. Check:"
    echo "   - Router port forwarding for 443 -> ${HOSTNAME}:443"
    echo "   - Firewall rules (ufw, iptables)"
    echo "   - Cloudflare proxy settings (try DNS-only mode)"
fi

if ! docker logs traefik 2>&1 | grep -q "certificateResolver=cloudflare"; then
    echo "⚠️  No services using Cloudflare certificates. Check:"
    echo "   - Service labels include: traefik.http.routers.X.tls.certresolver=cloudflare"
    echo "   - CLOUDFLARE_API_TOKEN is set correctly"
fi

echo ""
echo "Quick fixes to try:"
echo "1. Set Cloudflare to DNS-only mode (grey cloud)"
echo "2. Restart Traefik: docker restart traefik"
echo "3. Check .env file has DOMAIN=$DOMAIN"
echo "4. Verify port forwarding: 80->server:80, 443->server:443"
#
# Proxy utils
# ===========
#
# Usage: source THIS_FILE
#

PROXY_CERTFILE_TEMPLATE=/usr/local/share/ca-certificates/ca-cert-proxy-

# If environment variable https_proxy or HTTPS_PROXY is set then this function
# installs the proxy certificates as root certificates.
#
# Environment:
#   https_proxy,
#   HTTPS_PROXY    proxy URL; if both are set then https_proxy is used
#
install_proxy_certs() {
    local PROXY=${https_proxy:-$HTTPS_PROXY}

    # Install certificates for caching proxy, if present
    if [ -n "$PROXY" ]; then
        # Install root certificates and OpenSSL if necessary
        which openssl >/dev/null || apk add openssl
        which update-ca-certificates >/dev/null || apk add ca-certificates

        # Get the proxy certificates and install them as root certificates
        echo 'Q' \
        | openssl s_client \
            -connect 0.0.0.0:443 \
            -proxy ${PROXY##*://} \
            -showcerts \
            -verify 3 \
            2>/dev/null \
        | awk \
            -e '/-BEGIN CERTIFICATE-/ { p = 1; n++ }' \
            -e 'p > 0 { print >> "'$PROXY_CERTFILE_TEMPLATE'" n ".pem" }' \
            -e '/-END CERTIFICATE-/ { p = 0 }' \
        && update-ca-certificates
    fi
}


# --------------------------------------------------------------------------

# Removes proxy certificates that were installed as root certificates.
#
remove_proxy_certs() {
    rm -f ${PROXY_CERTFILE_TEMPLATE}*
    update-ca-certificates
}

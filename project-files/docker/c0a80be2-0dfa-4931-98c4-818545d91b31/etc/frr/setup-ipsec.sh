#!/bin/sh
set -eu

[ -r /etc/frr/gre.env ] && . /etc/frr/gre.env

# Static Linux XFRM/IPsec for GRE protocol 47 over the eth3 underlay.
# Shared secret used to derive these keys: bullshiter123
R1_UNDERLAY=10.0.1.1
R2_UNDERLAY=10.0.1.2
SPI_R1_R2=0x100
SPI_R2_R1=0x200
AUTH_R1_R2=0x51f29da7b03bf26e09c789f089f11615fdad900b95a0c08527db5293dd5d658d
ENC_R1_R2=0x6b2490e7dd44e6f94d42e630e3ae3462f3a5c0c0193a07e0c95f090cc52e9dd2
AUTH_R2_R1=0xe5408eefd20fabcf41cbea5923ffb0b9f737af33a614f39990d20f8b3110cb7b
ENC_R2_R1=0x5b87d113d12977acb55879dc4c8767363b895d46b1fa0703594f0806ade12602

ip xfrm policy delete src ${R1_UNDERLAY}/32 dst ${R2_UNDERLAY}/32 proto gre dir out 2>/dev/null || true
ip xfrm policy delete src ${R1_UNDERLAY}/32 dst ${R2_UNDERLAY}/32 proto gre dir in 2>/dev/null || true
ip xfrm policy delete src ${R2_UNDERLAY}/32 dst ${R1_UNDERLAY}/32 proto gre dir out 2>/dev/null || true
ip xfrm policy delete src ${R2_UNDERLAY}/32 dst ${R1_UNDERLAY}/32 proto gre dir in 2>/dev/null || true
ip xfrm state delete src ${R1_UNDERLAY} dst ${R2_UNDERLAY} proto esp spi ${SPI_R1_R2} 2>/dev/null || true
ip xfrm state delete src ${R2_UNDERLAY} dst ${R1_UNDERLAY} proto esp spi ${SPI_R2_R1} 2>/dev/null || true

ip xfrm state add src ${R1_UNDERLAY} dst ${R2_UNDERLAY} proto esp spi ${SPI_R1_R2} mode transport   auth 'hmac(sha256)' ${AUTH_R1_R2} enc 'cbc(aes)' ${ENC_R1_R2}
ip xfrm state add src ${R2_UNDERLAY} dst ${R1_UNDERLAY} proto esp spi ${SPI_R2_R1} mode transport   auth 'hmac(sha256)' ${AUTH_R2_R1} enc 'cbc(aes)' ${ENC_R2_R1}

case "${GRE_LOCAL:-}" in
  ${R1_UNDERLAY})
    ip xfrm policy add src ${R1_UNDERLAY}/32 dst ${R2_UNDERLAY}/32 proto gre dir out       tmpl src ${R1_UNDERLAY} dst ${R2_UNDERLAY} proto esp mode transport
    ip xfrm policy add src ${R2_UNDERLAY}/32 dst ${R1_UNDERLAY}/32 proto gre dir in       tmpl src ${R2_UNDERLAY} dst ${R1_UNDERLAY} proto esp mode transport
    ;;
  ${R2_UNDERLAY})
    ip xfrm policy add src ${R2_UNDERLAY}/32 dst ${R1_UNDERLAY}/32 proto gre dir out       tmpl src ${R2_UNDERLAY} dst ${R1_UNDERLAY} proto esp mode transport
    ip xfrm policy add src ${R1_UNDERLAY}/32 dst ${R2_UNDERLAY}/32 proto gre dir in       tmpl src ${R1_UNDERLAY} dst ${R2_UNDERLAY} proto esp mode transport
    ;;
  *)
    echo "GRE_LOCAL is unset or unexpected: ${GRE_LOCAL:-unset}" >&2
    exit 1
    ;;
esac

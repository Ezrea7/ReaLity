#!/bin/bash

_generate_reality_keys () 
{ 
    local keypair;
    keypair=$($XRAY_BIN x25519 2>&1);
    REALITY_PRIVATE_KEY=$(echo "$keypair" | awk -F' = ' '/PrivateKey/ {print $2; exit}');
    REALITY_PUBLIC_KEY=$(echo "$keypair" | awk -F' = ' '/PublicKey/ {print $2; exit}');
    [ -n "$REALITY_PRIVATE_KEY" ] || REALITY_PRIVATE_KEY=$(echo "$keypair" | awk '/PrivateKey/ {print $NF; exit}');
    [ -n "$REALITY_PUBLIC_KEY" ] || REALITY_PUBLIC_KEY=$(echo "$keypair" | awk '/PublicKey/ {print $NF; exit}');
    REALITY_SHORT_ID=$(openssl rand -hex 8);
    if [ -z "$REALITY_PRIVATE_KEY" ] || [ -z "$REALITY_PUBLIC_KEY" ]; then
        _error "Reality 密钥生成失败。";
        echo "$keypair" 1>&2;
        return 1;
    fi
}

_generate_singbox_reality_keys () 
{ 
    local keypair;
    [ -x "$SINGBOX_BIN" ] || { _error "Sing-box 内核未安装。"; return 1; };
    keypair=$($SINGBOX_BIN generate reality-keypair 2>&1);
    SINGBOX_REALITY_PRIVATE_KEY=$(echo "$keypair" | awk '/PrivateKey/ {print $2; exit}');
    SINGBOX_REALITY_PUBLIC_KEY=$(echo "$keypair" | awk '/PublicKey/ {print $2; exit}');
    SINGBOX_REALITY_SHORT_ID=$($SINGBOX_BIN generate rand --hex 8 2>/dev/null);
    [ -n "$SINGBOX_REALITY_SHORT_ID" ] || SINGBOX_REALITY_SHORT_ID=$(openssl rand -hex 8);
    if [ -z "$SINGBOX_REALITY_PRIVATE_KEY" ] || [ -z "$SINGBOX_REALITY_PUBLIC_KEY" ]; then
        _error "Sing-box Reality 密钥生成失败。";
        echo "$keypair" 1>&2;
        return 1;
    fi
}
_build_reality_stream () 
{ 
    local network="$1" sni="$2" private_key="$3" short_id="$4";
    jq -n --arg net "$network" --arg sni "$sni" --arg pk "$private_key" --arg sid "$short_id" '
        {
            "network": $net,
            "security": "reality",
            "realitySettings": {
                "show": false,
                "target": ($sni + ":443"),
                "xver": 0,
                "serverNames": [$sni],
                "privateKey": $pk,
                "shortIds": [$sid]
            }
        }'
}
_protocol_name () 
{ 
    case "$1" in 
        ss2022_reality)
            echo "SS + ReaLity"
        ;;
        trojan_reality)
            echo "Trojan + Reality"
        ;;
        vmess_reality)
            echo "VMess + Reality"
        ;;
        vless_vision_reality)
            echo "VLESS + Vision + Reality"
        ;;
        anytls_reality)
            echo "AnyTLS + Reality"
        ;;
        *)
            echo "$1"
        ;;
    esac
}
_protocol_default_name () 
{ 
    local protocol="$1" port="$2";
    case "$protocol" in 
        ss2022_reality)
            printf 'SS-REALITY-%s\n' "$port"
        ;;
        trojan_reality)
            printf 'TROJAN-REALITY-%s\n' "$port"
        ;;
        vmess_reality)
            printf 'VMESS-REALITY-%s\n' "$port"
        ;;
        vless_vision_reality)
            printf 'VLESS-REALITY-VISION-%s\n' "$port"
        ;;
        anytls_reality)
            printf 'ANYTLS-REALITY-%s\n' "$port"
        ;;
        *)
            printf '%s-%s\n' "$protocol" "$port"
        ;;
    esac
}
_protocol_add_node () 
{ 
    local protocol="$1";
    case "$protocol" in 
        ss2022_reality)
            _add_ss2022_reality
        ;;
        trojan_reality)
            _add_trojan_reality
        ;;
        vmess_reality)
            _add_vmess_reality
        ;;
        vless_vision_reality)
            _add_vless_vision_reality
        ;;
        anytls_reality)
            _add_anytls_reality
        ;;
        *)
            _error "暂不支持的协议: $protocol";
            return 1
        ;;
    esac
}
_ss2022_reality_method () 
{ 
    local choice
    echo ""
    echo -e "${YELLOW}请选择 SS + ReaLity 加密方式:${NC}"
    echo -e "  ${GREEN}[1]${NC} 2022-blake3-aes-128-gcm"
    echo -e "  ${GREEN}[2]${NC} aes-128-gcm"
    read -p "请选择 [1-2] (默认: 1): " choice
    case "${choice:-1}" in
        1) echo "2022-blake3-aes-128-gcm" ;;
        2) echo "aes-128-gcm" ;;
        *) _warn "无效选择，已使用默认加密方式 2022-blake3-aes-128-gcm。"; echo "2022-blake3-aes-128-gcm" ;;
    esac
}
_ss2022_reality_password () 
{ 
    openssl rand -base64 16
}
_build_ss2022_reality_inbound () 
{ 
    local tag="$1" port="$2" method="$3" password="$4" sni="$5" private_key="$6" short_id="$7";
    local stream;
    stream=$(_build_reality_stream "raw" "$sni" "$private_key" "$short_id");
    jq -n --arg tag "$tag" --argjson port "$port" --arg method "$method" --arg password "$password" --argjson stream "$stream" '
        {
            "tag": $tag,
            "listen": "::",
            "port": $port,
            "protocol": "shadowsocks",
            "settings": {
                "method": $method,
                "password": $password,
                "network": "tcp,udp"
            },
            "streamSettings": $stream
        }'
}
_add_ss2022_reality () 
{ 
    local protocol node_ip port sni name tag method password inbound qx_link;
    protocol="ss2022_reality";
    node_ip=$(_input_node_ip);
    port=$(_input_port);
    method=$(_ss2022_reality_method);
    sni=$(_input_sni "$DEFAULT_SNI");
    password=$(_ss2022_reality_password);
    _generate_reality_keys || return 1;
    name=$(_input_node_name "$protocol" "$port") || return 1;
    tag="$name";
    inbound=$(_build_ss2022_reality_inbound "$tag" "$port" "$method" "$password" "$sni" "$REALITY_PRIVATE_KEY" "$REALITY_SHORT_ID");
    _apply_xray_json_change ".inbounds += [$inbound]" || return 1;
    qx_link=$(_build_ss2022_reality_link "$tag" 2> /dev/null);
    _save_meta_bundle "$tag" "$name" "$qx_link" "protocol=${protocol}" "password=${password}" "publicKey=${REALITY_PUBLIC_KEY}" "shortId=${REALITY_SHORT_ID}" "server=${node_ip}" "sni=${sni}" "method=${method}";
    _finalize_added_node "SS+ReaLity" "$name" "$tag"
}
_trojan_reality_password () 
{ 
    local custom_password;
    read -p "请输入 Trojan 密码 (回车自动生成): " custom_password;
    if [ -n "$custom_password" ]; then
        printf '%s\n' "$custom_password";
    else
        openssl rand -base64 16;
    fi
}
_build_trojan_reality_inbound () 
{ 
    local tag="$1" port="$2" password="$3" sni="$4" private_key="$5" short_id="$6";
    local stream;
    stream=$(_build_reality_stream "raw" "$sni" "$private_key" "$short_id");
    jq -n --arg tag "$tag" --argjson port "$port" --arg password "$password" --argjson stream "$stream" '
        {
            "tag": $tag,
            "listen": "::",
            "port": $port,
            "protocol": "trojan",
            "settings": {
                "clients": [
                    {
                        "password": $password
                    }
                ]
            },
            "streamSettings": $stream
        }'
}
_add_trojan_reality () 
{ 
    local protocol node_ip port sni name tag password inbound qx_link;
    protocol="trojan_reality";
    node_ip=$(_input_node_ip);
    port=$(_input_port);
    sni=$(_input_sni "$DEFAULT_SNI");
    password=$(_trojan_reality_password);
    _generate_reality_keys || return 1;
    name=$(_input_node_name "$protocol" "$port") || return 1;
    tag="$name";
    inbound=$(_build_trojan_reality_inbound "$tag" "$port" "$password" "$sni" "$REALITY_PRIVATE_KEY" "$REALITY_SHORT_ID");
    _apply_xray_json_change ".inbounds += [$inbound]" || return 1;
    qx_link=$(_build_trojan_reality_link "$tag" 2> /dev/null);
    _save_meta_bundle "$tag" "$name" "$qx_link" "protocol=${protocol}" "password=${password}" "publicKey=${REALITY_PUBLIC_KEY}" "shortId=${REALITY_SHORT_ID}" "server=${node_ip}" "sni=${sni}";
    _finalize_added_node "Trojan+Reality" "$name" "$tag"
}
_build_vmess_reality_inbound () 
{ 
    local tag="$1" port="$2" uuid="$3" sni="$4" private_key="$5" short_id="$6";
    local stream;
    stream=$(_build_reality_stream "raw" "$sni" "$private_key" "$short_id");
    jq -n --arg tag "$tag" --argjson port "$port" --arg uuid "$uuid" --argjson stream "$stream" '
        {
            "tag": $tag,
            "listen": "::",
            "port": $port,
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": $uuid
                    }
                ]
            },
            "streamSettings": $stream
        }'
}
_add_vmess_reality () 
{ 
    local protocol node_ip port sni name tag uuid inbound qx_link;
    protocol="vmess_reality";
    node_ip=$(_input_node_ip);
    port=$(_input_port);
    sni=$(_input_sni "$DEFAULT_SNI");
    uuid=$(_input_uuid);
    _generate_reality_keys || return 1;
    name=$(_input_node_name "$protocol" "$port") || return 1;
    tag="$name";
    inbound=$(_build_vmess_reality_inbound "$tag" "$port" "$uuid" "$sni" "$REALITY_PRIVATE_KEY" "$REALITY_SHORT_ID");
    _apply_xray_json_change ".inbounds += [$inbound]" || return 1;
    qx_link=$(_build_vmess_reality_link "$tag" 2> /dev/null);
    _save_meta_bundle "$tag" "$name" "$qx_link" "protocol=${protocol}" "uuid=${uuid}" "publicKey=${REALITY_PUBLIC_KEY}" "shortId=${REALITY_SHORT_ID}" "server=${node_ip}" "sni=${sni}";
    _finalize_added_node "VMess+Reality" "$name" "$tag"
}
_build_vless_vision_reality_inbound () 
{ 
    local tag="$1" port="$2" uuid="$3" sni="$4" private_key="$5" short_id="$6";
    local stream;
    stream=$(_build_reality_stream "raw" "$sni" "$private_key" "$short_id");
    jq -n --arg tag "$tag" --argjson port "$port" --arg uuid "$uuid" --argjson stream "$stream" '
        {
            "tag": $tag,
            "listen": "::",
            "port": $port,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": $uuid,
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": $stream
        }'
}
_add_vless_vision_reality () 
{ 
    local protocol node_ip port sni name tag uuid inbound qx_link;
    protocol="vless_vision_reality";
    node_ip=$(_input_node_ip);
    port=$(_input_port);
    sni=$(_input_sni "$DEFAULT_SNI");
    uuid=$(_input_uuid);
    _generate_reality_keys || return 1;
    name=$(_input_node_name "$protocol" "$port") || return 1;
    tag="$name";
    inbound=$(_build_vless_vision_reality_inbound "$tag" "$port" "$uuid" "$sni" "$REALITY_PRIVATE_KEY" "$REALITY_SHORT_ID");
    _apply_xray_json_change ".inbounds += [$inbound]" || return 1;
    qx_link=$(_build_vless_vision_reality_link "$tag" 2> /dev/null);
    _save_meta_bundle "$tag" "$name" "$qx_link" "protocol=${protocol}" "uuid=${uuid}" "publicKey=${REALITY_PUBLIC_KEY}" "shortId=${REALITY_SHORT_ID}" "server=${node_ip}" "sni=${sni}";
    _finalize_added_node "VLESS+Vision+Reality" "$name" "$tag"
}

_build_anytls_reality_inbound () 
{ 
    local tag="$1" port="$2" password="$3" sni="$4" private_key="$5" short_id="$6";
    jq -n --arg t "$tag" --argjson p "$port" --arg pw "$password" --arg sn "$sni" --arg pk "$private_key" --arg sid "$short_id" '
        {
          "type": "anytls",
          "tag": $t,
          "listen": "::",
          "listen_port": $p,
          "users": [
            {
              "name": $t,
              "password": $pw
            }
          ],
          "tls": {
            "enabled": true,
            "server_name": $sn,
            "reality": {
              "enabled": true,
              "handshake": {
                "server": $sn,
                "server_port": 443
              },
              "private_key": $pk,
              "short_id": [
                $sid
              ]
            }
          }
        }'
}

_add_anytls_reality () 
{ 
    local protocol node_ip port sni name tag password inbound qx_link;
    protocol="anytls_reality";
    _require_singbox || return 1;
    _init_singbox_config;
    node_ip=$(_input_node_ip);
    port=$(_input_port);
    sni=$(_input_sni "$DEFAULT_SNI");
    read -p "请输入 AnyTLS 密码 (回车自动生成): " password;
    [ -n "$password" ] || password=$(openssl rand -hex 16);
    _generate_singbox_reality_keys || return 1;
    name=$(_input_node_name "$protocol" "$port") || return 1;
    tag="$name";
    inbound=$(_build_anytls_reality_inbound "$tag" "$port" "$password" "$sni" "$SINGBOX_REALITY_PRIVATE_KEY" "$SINGBOX_REALITY_SHORT_ID");
    _atomic_modify_json "$SINGBOX_CONFIG" ".inbounds += [$inbound]" || return 1;
    qx_link=$(_build_anytls_reality_link "$tag" 2> /dev/null);
    _save_meta_bundle "$tag" "$name" "$qx_link" "protocol=${protocol}" "password=${password}" "publicKey=${SINGBOX_REALITY_PUBLIC_KEY}" "shortId=${SINGBOX_REALITY_SHORT_ID}" "server=${node_ip}" "sni=${sni}";
    _finalize_added_node "AnyTLS+Reality" "$name" "$tag"
}

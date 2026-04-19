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
            echo "SS2022 + Reality"
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
            printf 'SS2022-REALITY-%s\n' "$port"
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
        *)
            _error "暂不支持的协议: $protocol";
            return 1
        ;;
    esac
}
_ss2022_reality_method () 
{ 
    echo "2022-blake3-aes-128-gcm"
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
    sni=$(_input_sni "$DEFAULT_SNI");
    method=$(_ss2022_reality_method);
    password=$(_ss2022_reality_password);
    _generate_reality_keys || return 1;
    name=$(_input_node_name "$protocol" "$port") || return 1;
    tag="$name";
    inbound=$(_build_ss2022_reality_inbound "$tag" "$port" "$method" "$password" "$sni" "$REALITY_PRIVATE_KEY" "$REALITY_SHORT_ID");
    _apply_xray_json_change ".inbounds += [$inbound]" || return 1;
    qx_link=$(_build_ss2022_reality_link "$tag" 2> /dev/null);
    _save_meta_bundle "$tag" "$name" "$qx_link" "protocol=${protocol}" "password=${password}" "publicKey=${REALITY_PUBLIC_KEY}" "shortId=${REALITY_SHORT_ID}" "server=${node_ip}" "sni=${sni}" "method=${method}";
    _finalize_added_node "SS2022+Reality" "$name" "$tag"
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

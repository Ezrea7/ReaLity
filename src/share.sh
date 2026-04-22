#!/bin/bash

_replace_port_in_text () 
{ 
    local text="$1" old_port="$2" new_port="$3";
    printf '%s' "$text" | sed "s/:${old_port}/:${new_port}/g; s/-${old_port}/-${new_port}/g"
}
_build_protocol_share_link () 
{ 
    local tag="$1" protocol;
    protocol=$(_get_meta_field "$tag" protocol);
    case "$protocol" in 
        ss2022_reality)
            _build_ss2022_reality_link "$tag"
        ;;
        trojan_reality)
            _build_trojan_reality_link "$tag"
        ;;
        vmess_reality)
            _build_vmess_reality_link "$tag"
        ;;
        vless_vision_reality)
            _build_vless_vision_reality_link "$tag"
        ;;
        anytls_reality)
            _build_anytls_reality_link "$tag"
        ;;
        *)
            return 1
        ;;
    esac
}
_get_share_link () 
{ 
    local tag="$1" saved_link built_link;
    saved_link=$(_get_meta_field "$tag" qx_link);
    [ -n "$saved_link" ] && { 
        echo "$saved_link";
        return 0
    };
    built_link=$(_build_protocol_share_link "$tag" 2> /dev/null);
    [ -n "$built_link" ] && { 
        echo "$built_link";
        return 0
    };
    return 1
}
_show_share_link () 
{ 
    local tag="$1" title="${2:-Quantumult X}" link;
    link=$(_get_share_link "$tag");
    [ -n "$link" ] || { 
        _warn "未能生成分享链接。";
        return 1
    };
    echo "";
    echo -e "  ${YELLOW}${title}:${NC} ${link}";
    echo ""
}
_show_vless_standard_share_link () 
{ 
    local tag="$1" link;
    link=$(_build_vless_vision_reality_std_link "$tag");
    [ -n "$link" ] || return 1;
    echo -e "  ${YELLOW}标准分享链接:${NC} ${link}";
    echo ""
}
_show_ss_standard_share_link () 
{ 
    local tag="$1" link;
    link=$(_build_ss_standard_link "$tag");
    [ -n "$link" ] || return 1;
    echo -e "  ${YELLOW}标准分享链接:${NC} ${link}";
    echo ""
}
_finalize_added_node () 
{ 
    local protocol_label="$1" name="$2" tag="$3";
    if [ "$(_protocol_of_tag "$tag")" = "anytls_reality" ]; then
        _manage_singbox_service restart;
    else
        _manage_xray_service restart;
    fi;
    _success "${protocol_label} 节点添加完成：${name}。";
    _show_share_link "$tag";
    if [ "$(_protocol_of_tag "$tag")" = "vless_vision_reality" ]; then
        _show_vless_standard_share_link "$tag";
    fi;
    if [ "$(_protocol_of_tag "$tag")" = "ss2022_reality" ] && [ "$(_get_meta_field "$tag" useReality)" != "true" ]; then
        _show_ss_standard_share_link "$tag";
    fi
}
_protocol_of_tag () 
{ 
    _get_meta_field "$1" protocol
}
_build_ss2022_reality_link () 
{ 
    local tag="$1";
    local port name method password sni public_key short_id server_ip link_ip use_reality;
    port=$(_get_inbound_field "$tag" '.port');
    [ -n "$port" ] || return 1;
    name=$(_get_tag_name "$tag");
    method=$(_get_meta_field "$tag" method);
    password=$(_get_meta_field "$tag" password);
    sni=$(_get_meta_field "$tag" sni);
    public_key=$(_get_meta_field "$tag" publicKey);
    short_id=$(_get_meta_field "$tag" shortId);
    server_ip=$(_get_meta_field "$tag" server);
    use_reality=$(_get_meta_field "$tag" useReality);
    [ -n "$method" ] || return 1;
    [ -n "$password" ] || return 1;
    [ -n "$server_ip" ] || return 1;
    link_ip="$server_ip";
    [[ "$link_ip" == *":"* ]] && link_ip="[$link_ip]";
    if [ "$use_reality" = "true" ]; then
        [ -n "$sni" ] || return 1;
        [ -n "$public_key" ] || return 1;
        [ -n "$short_id" ] || return 1;
        printf 'shadowsocks=%s:%s, method=%s, password=%s, obfs=over-tls, obfs-host=%s, tls-verification=false, reality-base64-pubkey=%s, reality-hex-shortid=%s, udp-relay=true, tag=%s\n' "$link_ip" "$port" "$method" "$password" "$sni" "$public_key" "$short_id" "$name"
    else
        printf 'shadowsocks=%s:%s, method=%s, password=%s, udp-relay=true, tag=%s\n' "$link_ip" "$port" "$method" "$password" "$name"
    fi
}

_build_ss_standard_link () 
{ 
    local tag="$1";
    local port name method password server_ip link_ip encoded_password;
    port=$(_get_inbound_field "$tag" '.port');
    [ -n "$port" ] || return 1;
    name=$(_get_tag_name "$tag");
    method=$(_get_meta_field "$tag" method);
    password=$(_get_meta_field "$tag" password);
    server_ip=$(_get_meta_field "$tag" server);
    [ -n "$method" ] || return 1;
    [ -n "$password" ] || return 1;
    [ -n "$server_ip" ] || return 1;
    link_ip="$server_ip";
    [[ "$link_ip" == *":"* ]] && link_ip="[$link_ip]";
    encoded_password=$(printf '%s' "$password" | sed 's/%/%25/g; s/+/%2B/g; s#/#%2F#g; s/=/%3D/g')
    printf 'ss://%s:%s@%s:%s#%s\n' "$method" "$encoded_password" "$link_ip" "$port" "$name"
}
_build_trojan_reality_link () 
{ 
    local tag="$1";
    local port name password sni public_key short_id server_ip link_ip;
    port=$(_get_inbound_field "$tag" '.port');
    [ -n "$port" ] || return 1;
    name=$(_get_tag_name "$tag");
    password=$(_get_meta_field "$tag" password);
    sni=$(_get_meta_field "$tag" sni);
    public_key=$(_get_meta_field "$tag" publicKey);
    short_id=$(_get_meta_field "$tag" shortId);
    server_ip=$(_get_meta_field "$tag" server);
    [ -n "$password" ] || return 1;
    [ -n "$sni" ] || return 1;
    [ -n "$public_key" ] || return 1;
    [ -n "$short_id" ] || return 1;
    [ -n "$server_ip" ] || return 1;
    link_ip="$server_ip";
    [[ "$link_ip" == *":"* ]] && link_ip="[$link_ip]";
    printf 'trojan=%s:%s, password=%s, over-tls=true, tls-host=%s, tls-verification=false, reality-base64-pubkey=%s, reality-hex-shortid=%s, udp-relay=true, tag=%s\n' "$link_ip" "$port" "$password" "$sni" "$public_key" "$short_id" "$name"
}
_build_vmess_reality_link () 
{ 
    local tag="$1";
    local port name uuid sni public_key short_id server_ip link_ip;
    port=$(_get_inbound_field "$tag" '.port');
    [ -n "$port" ] || return 1;
    name=$(_get_tag_name "$tag");
    uuid=$(_get_meta_field "$tag" uuid);
    sni=$(_get_meta_field "$tag" sni);
    public_key=$(_get_meta_field "$tag" publicKey);
    short_id=$(_get_meta_field "$tag" shortId);
    server_ip=$(_get_meta_field "$tag" server);
    [ -n "$uuid" ] || return 1;
    [ -n "$sni" ] || return 1;
    [ -n "$public_key" ] || return 1;
    [ -n "$short_id" ] || return 1;
    [ -n "$server_ip" ] || return 1;
    link_ip="$server_ip";
    [[ "$link_ip" == *":"* ]] && link_ip="[$link_ip]";
    printf 'vmess=%s:%s, method=none, password=%s, obfs=over-tls, obfs-host=%s, tls-verification=false, reality-base64-pubkey=%s, reality-hex-shortid=%s, udp-relay=true, tag=%s\n' "$link_ip" "$port" "$uuid" "$sni" "$public_key" "$short_id" "$name"
}
_build_vless_vision_reality_std_link () 
{ 
    local tag="$1";
    local port name uuid sni public_key short_id server_ip link_ip encoded_name;
    port=$(_get_inbound_field "$tag" '.port');
    [ -n "$port" ] || return 1;
    name=$(_get_tag_name "$tag");
    uuid=$(_get_meta_field "$tag" uuid);
    sni=$(_get_meta_field "$tag" sni);
    public_key=$(_get_meta_field "$tag" publicKey);
    short_id=$(_get_meta_field "$tag" shortId);
    server_ip=$(_get_meta_field "$tag" server);
    [ -n "$uuid" ] || return 1;
    [ -n "$sni" ] || return 1;
    [ -n "$public_key" ] || return 1;
    [ -n "$short_id" ] || return 1;
    [ -n "$server_ip" ] || return 1;
    link_ip="$server_ip";
    [[ "$link_ip" == *":"* ]] && link_ip="[$link_ip]";
    encoded_name=$(printf '%s' "$name" | sed 's/%/%25/g; s/ /%20/g; s/#/%23/g; s/?/%3F/g; s/&/%26/g; s/+/%2B/g');
    printf 'vless://%s@%s:%s?encryption=none&security=reality&sni=%s&fp=chrome&pbk=%s&sid=%s&type=tcp&flow=xtls-rprx-vision#%s\n' "$uuid" "$link_ip" "$port" "$sni" "$public_key" "$short_id" "$encoded_name"
}
_build_vless_vision_reality_link () 
{ 
    local tag="$1";
    local port name uuid sni public_key short_id server_ip link_ip;
    port=$(_get_inbound_field "$tag" '.port');
    [ -n "$port" ] || return 1;
    name=$(_get_tag_name "$tag");
    uuid=$(_get_meta_field "$tag" uuid);
    sni=$(_get_meta_field "$tag" sni);
    public_key=$(_get_meta_field "$tag" publicKey);
    short_id=$(_get_meta_field "$tag" shortId);
    server_ip=$(_get_meta_field "$tag" server);
    [ -n "$uuid" ] || return 1;
    [ -n "$sni" ] || return 1;
    [ -n "$public_key" ] || return 1;
    [ -n "$short_id" ] || return 1;
    [ -n "$server_ip" ] || return 1;
    link_ip="$server_ip";
    [[ "$link_ip" == *":"* ]] && link_ip="[$link_ip]";
    printf 'vless=%s:%s, method=none, password=%s, obfs=over-tls, obfs-host=%s, tls-verification=false, reality-base64-pubkey=%s, reality-hex-shortid=%s, udp-relay=true, vless-flow=xtls-rprx-vision, tag=%s\n' "$link_ip" "$port" "$uuid" "$sni" "$public_key" "$short_id" "$name"
}

_build_anytls_reality_link () 
{ 
    local tag="$1";
    local port name password sni public_key short_id server_ip link_ip;
    port=$(jq --arg tag "$tag" -r '.inbounds[] | select(.tag == $tag) | .listen_port // empty' "$SINGBOX_CONFIG" 2>/dev/null);
    [ -n "$port" ] || return 1;
    name=$(_get_tag_name "$tag");
    password=$(_get_meta_field "$tag" password);
    sni=$(_get_meta_field "$tag" sni);
    public_key=$(_get_meta_field "$tag" publicKey);
    short_id=$(_get_meta_field "$tag" shortId);
    server_ip=$(_get_meta_field "$tag" server);
    [ -n "$password" ] || return 1;
    [ -n "$sni" ] || return 1;
    [ -n "$public_key" ] || return 1;
    [ -n "$short_id" ] || return 1;
    [ -n "$server_ip" ] || return 1;
    link_ip="$server_ip";
    [[ "$link_ip" == *":"* ]] && link_ip="[$link_ip]";
    printf 'anytls=%s:%s, password=%s, over-tls=true, tls-host=%s, tls-verification=false, reality-base64-pubkey=%s, reality-hex-shortid=%s, udp-relay=true, tag=%s\n' "$link_ip" "$port" "$password" "$sni" "$public_key" "$short_id" "$name"
}

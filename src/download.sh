#!/bin/bash

_download_to() {
    local url="$1" output="$2"
    if command -v curl > /dev/null 2>&1; then
        curl -LfsS "$url" -o "$output"
    else
        if command -v wget > /dev/null 2>&1; then
            wget -q "$url" -O "$output"
        else
            return 1
        fi
    fi
}

_get_latest_repo_release_zip() {
    local api="https://api.github.com/repos/Ezrea7/Xray/releases/latest"
    local url
    url=$(_download_to "$api" /tmp/xtls_release.$$ 2>/dev/null || true)
    url=$(curl -fsSL "$api" | grep 'browser_download_url' | grep 'code.zip' | head -n1 | cut -d '"' -f4)
    [ -n "$url" ] || return 1
    printf '%s' "$url"
}
_pkg_install () 
{ 
    local pkgs="$*";
    [ -z "$pkgs" ] && return 0;
    if command -v apk > /dev/null 2>&1; then
        apk add --no-cache $pkgs > /dev/null 2>&1;
    else
        if command -v apt-get > /dev/null 2>&1; then
            if [ ! -d "/var/lib/apt/lists" ] || [ "$(ls -A /var/lib/apt/lists/ 2> /dev/null | wc -l)" -le 1 ]; then
                apt-get update -qq > /dev/null 2>&1;
            fi;
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $pkgs > /dev/null 2>&1 || { 
                apt-get update -qq > /dev/null 2>&1;
                DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $pkgs > /dev/null 2>&1
            };
        else
            if command -v dnf > /dev/null 2>&1; then
                dnf install -y $pkgs > /dev/null 2>&1;
            else
                if command -v yum > /dev/null 2>&1; then
                    yum install -y $pkgs > /dev/null 2>&1;
                fi;
            fi;
        fi;
    fi
}
_ensure_deps () 
{ 
    local missing="" still_missing="" c;
    for c in bash jq openssl awk sed grep unzip;
    do
        command -v "$c" > /dev/null 2>&1 || missing="$missing $c";
    done;
    command -v curl > /dev/null 2>&1 || command -v wget > /dev/null 2>&1 || missing="$missing curl";
    command -v ss > /dev/null 2>&1 || command -v netstat > /dev/null 2>&1 || _pkg_install iproute2 net-tools;
    if command -v apk > /dev/null 2>&1; then
        [ -f /etc/ssl/certs/ca-certificates.crt ] || missing="$missing ca-certificates";
    fi;
    [ -n "$missing" ] && _pkg_install $missing;
    for c in bash jq openssl awk sed grep unzip;
    do
        command -v "$c" > /dev/null 2>&1 || still_missing="$still_missing $c";
    done;
    command -v curl > /dev/null 2>&1 || command -v wget > /dev/null 2>&1 || still_missing="$still_missing curl";
    command -v ss > /dev/null 2>&1 || command -v netstat > /dev/null 2>&1 || still_missing="$still_missing iproute2/net-tools";
    if [ -n "$still_missing" ]; then
        _error "缺少依赖: ${still_missing# }";
        return 1;
    fi
}
_install_or_update_xray () 
{ 
    local is_first_install=false current_ver arch xray_arch download_url tmp_dir tmp_zip version;
    [ ! -f "$XRAY_BIN" ] && is_first_install=true;
    if [ "$is_first_install" = true ]; then
        _info "Xray 核心未安装，正在执行首次安装...";
    else
        current_ver=$($XRAY_BIN version 2> /dev/null | head -1 | awk '{print $2}');
        _info "当前 Xray 版本: v${current_ver}，正在检查更新...";
    fi;
    command -v unzip > /dev/null 2>&1 || _pkg_install unzip;
    arch=$(uname -m);
    xray_arch="64";
    case "$arch" in 
        x86_64 | amd64)
            xray_arch="64"
        ;;
        aarch64 | arm64)
            xray_arch="arm64-v8a"
        ;;
        armv7l)
            xray_arch="arm32-v7a"
        ;;
    esac;
    download_url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${xray_arch}.zip";
    tmp_dir=$(mktemp -d);
    tmp_zip="${tmp_dir}/xray.zip";
    _info "下载地址: ${download_url}";
    _download_to "$download_url" "$tmp_zip" || { 
        _error "Xray 下载失败。";
        rm -rf "$tmp_dir";
        return 1
    };
    unzip -qo "$tmp_zip" -d "$tmp_dir" || { 
        _error "Xray 解压失败。";
        rm -rf "$tmp_dir";
        return 1
    };
    [ -f "${tmp_dir}/xray" ] || { 
        _error "压缩包中未找到 xray 二进制。";
        rm -rf "$tmp_dir";
        return 1
    };
    mv "${tmp_dir}/xray" "$XRAY_BIN";
    chmod +x "$XRAY_BIN";
    mkdir -p "$XRAY_DIR";
    [ -f "${tmp_dir}/geoip.dat" ] && mv "${tmp_dir}/geoip.dat" "$XRAY_DIR/";
    [ -f "${tmp_dir}/geosite.dat" ] && mv "${tmp_dir}/geosite.dat" "$XRAY_DIR/";
    rm -rf "$tmp_dir";
    version=$($XRAY_BIN version 2> /dev/null | head -1 | awk '{print $2}');
    _success "Xray 内核安装/更新完成，当前版本: v${version}。";
    _init_xray_config;
    _create_xray_service;
    if [ "$is_first_install" = true ]; then
        _info "首次安装 Xray，正在初始化配置与服务...";
        _set_ip_preference ipv4 > /dev/null 2>&1 || true;
        _manage_xray_service start;
        _success "Xray 首次安装已完成，服务已启动。";
    else
        _manage_xray_service restart;
    fi
}
_update_script_self () 
{ 
    local tmpdir tmpzip relurl src staged_dir;
    relurl=$(_get_latest_repo_release_zip) || { 
        _error "获取最新 Release 失败。";
        return 1;
    };
    tmpdir=$(mktemp -d);
    tmpzip="$tmpdir/code.zip";
    src="$(readlink -f "$0" 2> /dev/null || printf '%s' "$0")";
    _download_to "$relurl" "$tmpzip" 2> /dev/null || { 
        rm -rf "$tmpdir";
        _error "下载更新失败。";
        return 1;
    };
    unzip -qo "$tmpzip" -d "$tmpdir" || { 
        rm -rf "$tmpdir";
        _error "更新包解压失败。";
        return 1;
    };
    staged_dir="$tmpdir";
    [ -f "$staged_dir/xray.sh" ] || { 
        rm -rf "$tmpdir";
        _error "更新包内容不完整。";
        return 1;
    };
    mkdir -p "$(dirname "$SCRIPT_INSTALL_PATH")" 2> /dev/null || true;
    cp -rf "$staged_dir"/* "$(dirname "$src")"/ 2> /dev/null || true;
    cp -f "$staged_dir/xray.sh" "$SCRIPT_INSTALL_PATH" || { 
        rm -rf "$tmpdir";
        _error "写入 ${SCRIPT_INSTALL_PATH} 失败。";
        return 1;
    };
    chmod +x "$SCRIPT_INSTALL_PATH" 2> /dev/null || true;
    if [ -n "$src" ] && [ -f "$src" ] && [ "$src" != "$SCRIPT_INSTALL_PATH" ]; then
        cp -f "$staged_dir/xray.sh" "$src" 2> /dev/null || true;
        chmod +x "$src" 2> /dev/null || true;
    fi;
    ln -sf "$SCRIPT_INSTALL_PATH" "$SCRIPT_ALIAS_PATH" 2> /dev/null || cp -f "$SCRIPT_INSTALL_PATH" "$SCRIPT_ALIAS_PATH" 2> /dev/null || true;
    chmod +x "$SCRIPT_ALIAS_PATH" 2> /dev/null || true;
    rm -rf "$tmpdir";
    _success "脚本更新完成。当前快捷命令: ${SCRIPT_CMD_NAME} / ${SCRIPT_CMD_ALIAS}";
    _warn "请重新运行 ${SCRIPT_CMD_NAME} 或 ${SCRIPT_CMD_ALIAS} 以加载新版本。"
}

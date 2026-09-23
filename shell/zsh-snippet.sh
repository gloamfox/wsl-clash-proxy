# ===== WSL Clash Proxy Auto-Load (managed by wsl-clash-proxy) =====
[ -f "$HOME/.config/wsl-clash-proxy/wsl-proxy.env" ] && source "$HOME/.config/wsl-clash-proxy/wsl-proxy.env"

_proxy_refresh() {
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
    [ -f "$HOME/.config/wsl-clash-proxy/wsl-proxy.env" ] && source "$HOME/.config/wsl-clash-proxy/wsl-proxy.env"
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _proxy_refresh
# ===== End WSL Clash Proxy =====
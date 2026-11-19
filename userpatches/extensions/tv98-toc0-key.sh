function pre_config_uboot_target__tv98_toc0_key() {
    local key="${SRC}/userpatches/tv98-root-key.pem"
    if [ ! -s "$key" ]; then
        (umask 077; openssl genrsa -out "$key" 2048) || return 1
    fi
    install -m 600 "$key" root_key.pem
}

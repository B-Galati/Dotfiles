#!/usr/bin/env bash
#

info () {
    printf "  [ \033[00;34m..\033[0m ] %s\n" "$1"
}

success () {
    printf "\r\033[2K  [ \033[00;32mOK\033[0m ] %s\n" "$1"
}

fail () {
    printf "\r\033[2K  [\033[0;31mFAIL\033[0m] %s\n" "$1"
}

linkFiles () {
    if [[ -L $2 ]]; then
        info "SKIP '$1' -> symlink already exists in '$2'"
        return 0;
    fi

    if [[ -d $2  && ! -L $2 ]]; then
        read -p "Directory '$2' already exists. Do you want to sync it and create symlink ?(y/n) " -n 1;
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rsync -ah $2 $(dirname $1)
            rm -rf $2
        else
            return 0;
        fi
    fi

    if ln -snf $1 $2; then
        success "linked $1 to $2"
    else
        fail "linked $1 to $2"
    fi
}

doIt () {
    # Création des fichiers de config
    for file in $(find $PWD \
        -maxdepth 1 \
        -name ".*" \
        -not -name ".gitignore" \
        -not -name ".extra" \
        -not -name ".gitconfig_private" \
        -not -name ".git" \
        -not -name ".btsync" \
        -not -name "*.swp" \
        -not -path "*.gitmodules*" \
        -not -path "*.git/*")
    do
        linkFiles $file "$HOME/$(basename $file)"
    done

    # btsync does not follow symlink :-)
    if [[ ! -d "$HOME/.btsync" ]]; then mkdir "$HOME/.btsync"; fi
    if ln -f "$PWD/.btsync/btsync.conf" "$HOME/.btsync/btsync.conf"; then
        success "Hardlink for btsync"
    else
        fail "Hardlink for btsync"
    fi

    # Add config files in /etc/
    for file in $(find $PWD/etc -type f -not -name ".*.swp")
    do
        f=$(echo $file | sed -e "s|$PWD||")
        if sudo ln -f $file $f; then
            success "Hardlink for $file to $f"
        else
            fail "Hardlink for $file to $f"
        fi
    done
    systemctl --user daemon-reload
    sudo systemctl daemon-reload
    sudo sysctl --system

    # add aliases for things in bin
    for file in $(find $PWD/bin -type f -not -name ".*.swp")
    do
        f="/usr/local/bin/$(basename $file)"
        if [[ -L $f ]]; then
            info "SKIP '$file' -> symlink already exists in '$f'"
            continue
        fi
        if sudo ln -snf $file $f; then
            success "linked $file to $f"
        else
            fail "linked $file to $f"
        fi
    done

    # Create private files if does not exist
    for file in ".extra" ".gitconfig_private"
    do
        if [[ ! -f "$HOME/$file" ]]; then
            cp $file $HOME
            success "Create $file in home $HOME"
        else
            info "SKIP private file '$file' -> already exists"
        fi
    done
}

cd "$(dirname "${BASH_SOURCE}")"

if [[ "$1" == "--force" || "$1" == "-f" ]]; then
    doIt
else
    read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1;
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        doIt
    fi
fi

unset doIt


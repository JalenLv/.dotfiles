#!/usr/bin/bash

sudo apt install -y fcitx5 fcitx5-chinese-addons fcitx5-rime
im-config -n fcitx5

echo "please reboot"

rime_frontend=fcitx-rime bash <(curl -fsSL https://raw.githubusercontent.com/rime/plum/master/rime-install) iDvel/rime-ice

n=3
for (( i = 1; i <= n; i++ )); do
  rime_frontend=fcitx-rime bash <(curl -fsSL https://raw.githubusercontent.com/rime/plum/master/rime-install) iDvel/rime-ice:others/recipes/grammar:schema=rime_ice && break
  if (( i < n )); then
    echo "attempt $i failed, retrying in 30s"; sleep 30
  else
    echo "all $n attempts failed" >&2
  fi
done

mkdir -p $HOME/.local/share/fcitx5/themes
wget -qO- https://github.com/Reverier-Xu/Fluent-fcitx5/archive/refs/heads/master.tar.gz | tar -xz -C $HOME/.local/share/fcitx5/themes --strip-components=1 --wildcards '*/Fluent*'

echo "use fcitx5-configtool gui to"
echo "  - add rime"
echo "  - deploy rime"
echo "  - change keymaps"




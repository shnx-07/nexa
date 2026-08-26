#!/bin/bash

hyprctl clients -j | jq -r '.[].address' | while read addr; do
  hyprctl dispatch movetoworkspacesilent special:desktop,address:$addr
done

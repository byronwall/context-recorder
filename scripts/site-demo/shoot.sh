#!/bin/zsh
# Screenshot the Sessions window on the demo session, for the site.
#   scripts/site-demo/shoot.sh <name> <app args...>   e.g. shoot.sh region --mark 3
# Needs `swift build --product ContextRecorder` and make_session.py first. Writes tmp/site-shots/<name>.png.
# CR_CLOUD_URL points at nothing, so cloud sessions from other Macs stay out of the sidebar.
name=$1; shift
cd "${0:A:h}/../.."
mkdir -p tmp/site-shots
[[ -x tmp/winid ]] || swiftc scripts/site-demo/winid.swift -o tmp/winid
CR_CLOUD_URL=http://127.0.0.1:9 .build/debug/ContextRecorder --library "$PWD/tmp/site-demo" --session 2026-11-19_10-42-00 --window-width 1440 "$@" > tmp/app.log 2>&1 &
pid=$!
for i in {1..30}; do id=$(tmp/winid $pid | awk 'NR==1{print $1}'); [[ -n $id ]] && break; sleep 1; done
sleep ${WAIT:-4}
screencapture -x -o -l $id tmp/site-shots/$name.png
kill $pid
echo tmp/site-shots/$name.png

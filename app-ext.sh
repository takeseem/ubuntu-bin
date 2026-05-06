#!/bin/bash -e

###############################################################################
# Description: AppImage Unpacker & System Integrator
# Usage: ./app-ext.sh <YourApp.AppImage>
#
# Features:
#   1. Unpacks AppImage to a local directory (persistent, avoids IO overhead).
#   2. Automatically extracts and fixes the .desktop file.
#   3. Updates the system menu (XDG) for easy launching and taskbar pinning.
#   4. Sets absolute paths for Exec and Icon to ensure portability.
###############################################################################

mypwd=$(pwd)
echo -e "$(date +"%Y-%m-%d %H:%M:%S") === $$ $mypwd ===\n  $0 $@"
[[ ! -f $1 ]] && echo "\$1: AppImage not exist '$1'" && exit 1

myappimg=$1
myname=$(basename $myappimg)
myname=${myname%.AppImage}
echo "./$myappimg --appimage-extract -> $myname"
[[ -s "$myname" ]] && echo "$myname exist" && exit 1
[[ ! -x $mypwd/$myappimg ]] && chmod u+x $mypwd/$myappimg
mkdir -p $myname && (cd $myname && $mypwd/$myappimg --appimage-extract)
myname0=${myname%%-[0-9]*}
[[ "$myname0" == "$myname" ]] && myname0=${myname%%_[0-9]*}
myname0=${myname0%%_x86*}
myname0=${myname0,,}
ln -sf -T $myname $myname0-ver

APPDIR=$mypwd/$myname0-ver/squashfs-root
myappdesk=$(ls $APPDIR/*.desktop)
mydesk=$(basename $myappdesk)
mydesk=${mydesk#@}
echo "create $mydesk from $myappdesk"
cp -rp $myappdesk $mydesk
myapprun=$(ls app-run app-run.sh 2>/dev/null || echo "")
if [ -f "$myapprun" ]; then
    echo "AppRun -> $(pwd)/$myapprun"
    sed -i "s|Exec=AppRun|Exec=env APPDIR=$APPDIR $(pwd)/$myapprun|" $mydesk
else
    sed -i "s|Exec=|Exec=env APPDIR=$APPDIR ./|" $mydesk
fi
sed -i "s|Icon=.*|Icon=$APPDIR/.DirIcon|" $mydesk
sed -i '/^category=/d' $mydesk
echo "Path=$APPDIR" >> $mydesk

echo "desktop-file-validate $mydesk: `desktop-file-validate $mydesk && echo OK`"

echo "ln -sf -T $mydesk -> ~/.local/share/applications/$mydesk"
ln -sf -T "$(pwd)/$mydesk" ~/.local/share/applications/$mydesk
echo "update-desktop-database ~/.local/share/applications `update-desktop-database ~/.local/share/applications && echo OK`"

myxhandler=$(grep -i "MimeType=.*x-scheme-handler/lmstudio;" $mydesk)
if [ -n "$myxhandler" ]; then
    myxscheme=${myxhandler##*x-scheme-handler/}
    myxscheme=${myxscheme%%;*}
    echo "$myxhandler"
    echo "gio mime x-scheme-handler/$myxscheme"
    gio mime x-scheme-handler/$myxscheme
    echo "xdg-open $myxscheme://test"
    # xdg-open $myxscheme://test
fi

echo "$(date +"%Y-%m-%d %H:%M:%S") === Done ==="

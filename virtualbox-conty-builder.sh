#!/bin/sh

set -u
APP=virtualbox

# CREATE A TEMPORARY DIRECTORY
mkdir -p tmp && cd tmp || exit 1

# DOWNLOADING APPIMAGETOOL
if test -f ./appimagetool; then
	echo " appimagetool already exists" 1> /dev/null
else
	echo " Downloading appimagetool..."
	wget -q "$(wget -q https://api.github.com/repos/probonopd/go-appimage/releases -O - | sed 's/"/ /g; s/ /\n/g' | grep -o 'https.*continuous.*tool.*86_64.*mage$')" -O appimagetool
fi
chmod a+x ./appimagetool

# CREATE AND ENTER THE APPDIR
mkdir -p "$APP".AppDir && cd "$APP".AppDir || exit 1

# ICON
if ! test -f ./*.svg; then
	wget -q https://upload.wikimedia.org/wikipedia/commons/d/d5/Virtualbox_logo.png -O virtualbox.png
fi

# LAUNCHER
echo "[Desktop Entry]
Name=VirtualBox
GenericName=PC virtualization solution

Type=Application
Exec=AppRun %U
Keywords=virtualization;
Keywords[de]=Virtualisierung;
Keywords[ru]=виртуализация;
MimeType=application/x-virtualbox-vbox;application/x-virtualbox-vbox-extpack;application/x-virtualbox-ovf;application/x-virtualbox-ova;
Icon=virtualbox
Categories=System;
Comment=Run several virtual systems on a single host computer
Comment[de]=Mehrere virtuelle Maschinen auf einem einzigen Rechner ausführen
Comment[it]=Esegui più macchine virtuali su un singolo computer
Comment[ko]=가상 머신
Comment[pl]=Uruchamianie wielu systemów wirtualnych na jednym komputerze gospodarza
Comment[ru]=Запуск нескольких виртуальных машин на одном компьютере
Comment[sv]=Kör flera virtuella system på en enda värddator" > "$APP".desktop

# APPRUN
rm -f ./AppRun
cat >> ./AppRun << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
export UNION_PRELOAD="${HERE}"
"${HERE}"/conty.sh virtualbox "$@"
EOF
chmod a+x ./AppRun

# DOWNLOAD CONTY
if ! test -f ./*.sh; then
	conty_download_url=$(curl -Ls https://api.github.com/repos/ivan-hc/Conty/releases | sed 's/[()",{} ]/\n/g' | grep -oi "https.*virtualbox.*sh$" | head -1)
	echo " Downloading Conty..."
	if wget --version | head -1 | grep -q ' 1.'; then
		wget -q --no-verbose --show-progress --progress=bar "$conty_download_url"
	else
		wget "$conty_download_url"
	fi
	chmod a+x ./conty.sh
fi

# EXIT THE APPDIR
cd .. || exit 1

# EXPORT THE APPDIR TO AN APPIMAGE
VERSION=$(curl -Ls https://gitlab.com/chaotic-aur/pkgbuilds/-/raw/main/virtualbox-kvm/PKGBUILD | grep vboxver | head -1 | tr "'" '\n' | grep "^[0-9]")
ARCH=x86_64 VERSION="$VERSION" ./appimagetool -s ./"$APP".AppDir
cd .. && mv ./tmp/*.AppImage ./VirtualBox-KVM-"$VERSION"-x86_86.AppImage || exit 1


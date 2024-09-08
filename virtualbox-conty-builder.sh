#!/bin/sh

set -u
APP=virtualbox
VERSION=$(curl -Ls https://gitlab.com/chaotic-aur/pkgbuilds/-/raw/main/virtualbox-kvm/PKGBUILD | grep vboxver | head -1 | tr "'" '\n' | grep "^[0-9]")

# CREATE A TEMPORARY DIRECTORY
mkdir -p tmp && cd tmp || exit 1

# DOWNLOADING APPIMAGETOOL
if test -f ./appimagetool; then
	echo " appimagetool already exists" 1> /dev/null
else
	echo " Downloading appimagetool..."
	wget -q https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
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

Show_help_message() {
	printf " Available options:\n"
	printf "\n  --vbox-usb-enable\n"
	printf "\n	Enable USB support in Virtual Machines. Requires \"sudo\" password.\n"
	printf "\n	The above option does the following:\n"
	printf "\n	- Creates the \"vboxusers\" group"
	printf "\n	- Adds your \$USER to the \"vboxusers\" group"
	printf "\n	- Creates the /usr/lib/virtualbox directory on the host system"
	printf "\n	- Installs the \"VBoxCreateUSBNode.sh\" script in /usr/lib/virtualbox"
	printf "\n	- Creates the /etc/udev/rules.d directory"
	printf "\n	- Creates and installs the \"60-vboxusb.rules\" file in /etc/udev/rules.d\n"
	printf "\n  VirtualBoxVM\n"
	printf "\n	A VirtualBox command to handle Virtual Machines via command line\n\n"
}

VBoxUSB_enable() {
	printf "\n The above option does the following:\n"
	printf "\n - Creates the \"vboxusers\" group"
	printf "\n - Adds your \$USER to the \"vboxusers\" group"
	printf "\n - Creates the /usr/lib/virtualbox directory on the host system"
	printf "\n - Installs the \"VBoxCreateUSBNode.sh\" script in /usr/lib/virtualbox"
	printf "\n - Creates the /etc/udev/rules.d directory"
	printf "\n - Creates and installs the \"60-vboxusb.rules\" file in /etc/udev/rules.d\n"
	printf "\n See also https://github.com/cyberus-technology/virtualbox-kvm#usb-pass-through\n"
	printf "\nAuthentication is required\n"
	if ! test -f /usr/lib/virtualbox/VBoxCreateUSBNode.sh; then
		# Create the "vboxusers" group and add $USER
		sudo groupadd -r vboxusers -U "$USER" 
		# Create the directory /usr/lib/virtualbox on the host system
		sudo mkdir -p /usr/lib/virtualbox
		# Install the "VBoxCreateUSBNode.sh" script in /usr/lib/virtualbox
		QUIET_MODE=1 NVIDIA_HANDLER=0 "${HERE}"/conty.sh cp /usr/share/virtualbox/VBoxCreateUSBNode.sh ./
		chmod a+x VBoxCreateUSBNode.sh
		sudo mv VBoxCreateUSBNode.sh /usr/lib/virtualbox/
		sudo chown -R root:vboxusers /usr/lib/virtualbox
	fi
	if ! test -f /etc/udev/rules.d/60-vboxusb.rules; then
		# Create the directory /etc/udev/rules.d
		sudo mkdir -p /etc/udev/rules.d
		# Create and install the 60-vboxusb.rules file in /etc/udev/rules.d
		cat <<-'HEREDOC' >> ./60-vboxusb.rules
		SUBSYSTEM=="usb_device", ACTION=="add", RUN+="/usr/lib/virtualbox/VBoxCreateUSBNode.sh $major $minor $attr{bDeviceClass}"
		SUBSYSTEM=="usb", ACTION=="add", ENV{DEVTYPE}=="usb_device", RUN+="/usr/lib/virtualbox/VBoxCreateUSBNode.sh $major $minor $attr{bDeviceClass}"
		SUBSYSTEM=="usb_device", ACTION=="remove", RUN+="/usr/lib/virtualbox/VBoxCreateUSBNode.sh --remove $major $minor"
		SUBSYSTEM=="usb", ACTION=="remove", ENV{DEVTYPE}=="usb_device", RUN+="/usr/lib/virtualbox/VBoxCreateUSBNode.sh --remove $major $minor"
		HEREDOC
		sudo mv 60-vboxusb.rules /etc/udev/rules.d/
		# Reload the udev rules
		sudo systemctl reload systemd-udevd
	fi
	printf "\nIt is recommended that you reboot for the changes to take effect.\n"
}

case "$1" in
	'')
		"${HERE}"/conty.sh virtualbox
		;;
	'VirtualBoxVM')
		"${HERE}"/conty.sh "$1" "$@"
		;;
	'-h'|'--help')
		Show_help_message
		;;
	'--vbox-usb-enable')
		VBoxUSB_enable
		;;
	'-v'|'--version')
		echo "VirtualBox VERSION KVM"
		;;
	'virtualbox'|*) "${HERE}"/conty.sh VirtualBox "$@"
	;;
esac | grep -v "You\|vboxdrv\|available for the current kernel\|Please recompile the kernel module\|sudo /sbin/vboxconfig"
EOF
chmod a+x ./AppRun
sed -i "s/VERSION/$VERSION/g" ./AppRun

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
ARCH=x86_64 ./appimagetool --comp zstd --mksquashfs-opt -Xcompression-level --mksquashfs-opt 1 \
	-u "gh-releases-zsync|$GITHUB_REPOSITORY_OWNER|VirtualBox-appimage|continuous|*x86_64.AppImage.zsync" \
	./"$APP".AppDir VirtualBox-KVM-"$VERSION"-x86_64.AppImage
cd .. && mv ./tmp/*.AppImage* ./ || exit 1

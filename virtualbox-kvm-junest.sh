#!/usr/bin/env bash

APP=virtualbox-kvm
BIN="virtualbox" #CHANGE THIS IF THE NAME OF THE BINARY IS DIFFERENT FROM "$APP" (for example, the binary of "obs-studio" is "obs")
audio_pkgs="alsa-lib alsa-oss alsa-plugins alsa-tools alsa-utils flac jack2 lame libogg libpipewire libpulse libvorbis mpg123 opus pipewire pipewire-alsa pipewire-audio pulseaudio pulseaudio-alsa"
vulkan_pkgs="libdisplay-info libdrm libxcb libxshmfence llvm-libs spirv-tools vulkan-asahi vulkan-gfxstream vulkan-icd-loader vulkan-intel vulkan-mesa-implicit-layers vulkan-nouveau vulkan-radeon vulkan-swrast vulkan-tools vulkan-virtio"
DEPENDENCES=$(echo "$audio_pkgs $vulkan_pkgs dbus libasyncns libsndfile procps-ng qt6-base" | tr ' ' '\n' | sort -u | xargs) #SYNTAX: "APP1 APP2 APP3 APP4...", LEAVE BLANK IF NO OTHER DEPENDENCIES ARE NEEDED
BASICSTUFF="binutils debugedit gzip"
COMPILERS="base-devel"

# Set keywords to searchan include in names of directories and files in /usr/bin (BINSAVED), /usr/share (SHARESAVED) and /usr/lib (LIBSAVED)
BINSAVED="kmod lsmod ldconfig"
SHARESAVED="alsa"
LIBSAVED="ibicui libxcb-cursor libxcb-util.so libxml pulse DBus"

# Set the items you want to manually REMOVE. Complete the path in /etc/, /usr/bin/, /usr/lib/, /usr/lib/python*/ and /usr/share/ respectively.
# The "rm" command will take into account the listed object/path and add an asterisk at the end, completing the path to be removed.
# Some keywords and paths are already set. Remove them if you consider them necessary for the AppImage to function properly.
ETC_REMOVED="makepkg.conf pacman"
BIN_REMOVED="gcc"
LIB_REMOVED="cmake gcc gconv libgphobos"
PYTHON_REMOVED="__pycache__/"
SHARE_REMOVED="gcc icons/AdwaitaLegacy icons/Adwaita/cursors/ terminfo i18n"

# Set mountpoints, they are ment to be set into the AppRun.
# Default mounted files are /etc/resolv.conf, /etc/hosts, /etc/nsswitch.conf, /etc/passwd, /etc/group, /etc/machine-id, /etc/asound.conf and /etc/localtime
# Default mounted directories are /media, /mnt, /opt, /run/media, /usr/lib/locale, /usr/share/fonts, /usr/share/themes, /var, and Nvidia-related directories
# Do not touch this if you are not sure.
mountpoint_files=""
mountpoint_dirs=""

# Post-installation processes (add whatever you want)
_post_installation_processes() {
	printf "\n◆ User's processes: \n\n"

	#############################################################################
	#	PATCH FOR VIRTUALBOX
	#############################################################################

	sed -i "s/VERSION/$vboxver/g" AppDir/AppRun

	# Workaround locale troubles (in some releases the language is not correctly detected)
	mkdir -p AppDir/.junest/usr/lib/virtualbox/nls
	cp -r AppDir/.junest/usr/share/virtualbox/nls/* AppDir/.junest/usr/lib/virtualbox/nls/

	# Add guest additions
	if ! test -f ./VBoxGuestAdditions.iso; then
		wget https://download.virtualbox.org/virtualbox/"${vboxver}"/VBoxGuestAdditions_"${vboxver}".iso -O ./VBoxGuestAdditions.iso || exit 1
	fi
	mkdir -p AppDir/.junest/usr/lib/virtualbox/additions
	cp -r VBoxGuestAdditions.iso AppDir/.junest/usr/lib/virtualbox/additions/ || exit 1

	# Add extension pack
	if ! test -f ./Extension_Pack.tar; then
		wget https://download.virtualbox.org/virtualbox/"${vboxver}"/Oracle_VirtualBox_Extension_Pack-"${vboxver}".vbox-extpack -O ./Extension_Pack.tar
	fi
	mkdir -p shrunk
	tar xfC ./Extension_Pack.tar shrunk
	rm -r shrunk/{darwin*,solaris*,win*}
	tar -c --gzip --file shrunk.vbox-extpack -C shrunk .
	mkdir -p AppDir/.junest/usr/share/virtualbox/extensions
	cp -r shrunk.vbox-extpack AppDir/.junest/usr/share/virtualbox/extensions/Oracle_VirtualBox_Extension_Pack-"${vboxver}".vbox-extpack
	mkdir -p AppDir/.junest/usr/share/licenses/virtualbox-ext-oracle/
	cp -r shrunk/ExtPack-license.txt AppDir/.junest/usr/share/licenses/virtualbox-ext-oracle/PUEL
	mkdir -p AppDir/.junest/usr/lib/virtualbox/ExtensionPacks/Oracle_VirtualBox_Extension_Pack
	cp -r shrunk/* AppDir/.junest/usr/lib/virtualbox/ExtensionPacks/Oracle_VirtualBox_Extension_Pack/

	# Install the "VBoxCreateUSBNode.sh" script in /usr/lib/virtualbox
	mkdir -p AppDir/.junest/usr/lib/virtualbox
	cp -r AppDir/.junest/usr/share/virtualbox/VBoxCreateUSBNode.sh AppDir/.junest/usr/lib/virtualbox/
	chown -R root:vboxusers AppDir/.junest/usr/lib/virtualbox

	# Create and install the 60-vboxusb.rules file in /etc/udev/rules.d
	mkdir -p AppDir/.junest/etc/udev/rules.d
	cat <<-'HEREDOC' >> AppDir/.junest/etc/udev/rules.d/60-vboxusb.rules
	SUBSYSTEM=="usb_device", ACTION=="add", RUN+="/usr/lib/virtualbox/VBoxCreateUSBNode.sh $major $minor $attr{bDeviceClass}"
	SUBSYSTEM=="usb", ACTION=="add", ENV{DEVTYPE}=="usb_device", RUN+="/usr/lib/virtualbox/VBoxCreateUSBNode.sh $major $minor $attr{bDeviceClass}"
	SUBSYSTEM=="usb_device", ACTION=="remove", RUN+="/usr/lib/virtualbox/VBoxCreateUSBNode.sh --remove $major $minor"
	SUBSYSTEM=="usb", ACTION=="remove", ENV{DEVTYPE}=="usb_device", RUN+="/usr/lib/virtualbox/VBoxCreateUSBNode.sh --remove $major $minor"
	HEREDOC

	# Allow VirtualBox to be used in PROOT mode
	sed -i 's#^MY_DIR=.*#MY_DIR="${JUNEST_HOME}/usr/lib/virtualbox"#g' AppDir/.junest/usr/bin/VBox || exit 1

	# Remove annoying vboxdrv messages
	sed -i 's/elif ! lsmod/elif ! echo vboxdrv/g' AppDir/.junest/usr/bin/VBox || exit 1
	sed -i 's# ! -c /dev/vboxdrv# -d /dev/vboxdrv#g' AppDir/.junest/usr/bin/VBox || exit 1
}

vboxver=$(curl -Ls https://gitlab.com/chaotic-aur/pkgbuilds/-/raw/main/virtualbox-kvm/PKGBUILD | grep vboxver | head -1 | tr "'" '\n' | grep "^[0-9]")
export ICON="virtualbox.png"

##########################################################################################################################################################
#	SETUP THE ENVIRONMENT
##########################################################################################################################################################

# Download archimage-builder.sh
if [ ! -f ./archimage-builder.sh ]; then
	ARCHIMAGE_BUILDER="https://raw.githubusercontent.com/ivan-hc/ArchImage/refs/heads/main/core/archimage-builder.sh"
	wget --retry-connrefused --tries=30 "$ARCHIMAGE_BUILDER" -O ./archimage-builder.sh || exit 0
fi

# Create and enter the AppDir
mkdir -p AppDir archlinux && cd archlinux || exit 1

_JUNEST_CMD() {
	./.local/share/junest/bin/junest "$@"
}

# Set archlinux as a temporary $HOME directory
HOME="$(dirname "$(readlink -f "$0")")"

##########################################################################################################################################################
#	DOWNLOAD, INSTALL AND CONFIGURE JUNEST
##########################################################################################################################################################

_enable_archlinuxcn() {	ARCHLINUXCN_ON="1"; }
_enable_chaoticaur() { CHAOTICAUR_ON="1"; }
_enable_multilib() { MULTILIB_ON="1"; }

#_enable_archlinuxcn
_enable_chaoticaur
#_enable_multilib

[ -f ../archimage-builder.sh ] && source ../archimage-builder.sh junest-setup "$@"

##########################################################################################################################################################
#	INSTALL PROGRAMS USING YAY
##########################################################################################################################################################

[ -f ../archimage-builder.sh ] && source ../archimage-builder.sh install "$@"

cd ..

##########################################################################################################################################################
#	APPDIR
##########################################################################################################################################################

[ -f ./archimage-builder.sh ] && source ./archimage-builder.sh appdir "$@"

##########################################################################################################################################################
#	APPRUN
##########################################################################################################################################################

rm -f AppDir/AppRun

# Set to "1" if you want to add Nvidia drivers manager in the AppRun
export NVIDIA_ON=1

[ -f ./archimage-builder.sh ] && source ./archimage-builder.sh apprun "$@"

# AppRun footer, here you can add options and change the way the AppImage interacts with its internal structure
cat <<-'HEREDOC' >> AppDir/AppRun

if command -v sudo >/dev/null 2>&1; then
    export SUDOCMD="sudo"
elif command -v doas >/dev/null 2>&1; then
    export SUDOCMD="doas"
else
    echo 'ERROR: No sudo or doas found'
    exit 1
fi

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
        $SUDOCMD groupadd -r vboxusers -U "$USER" 
        # Create the directory /usr/lib/virtualbox on the host system
        $SUDOCMD mkdir -p /usr/lib/virtualbox
        # Install the "VBoxCreateUSBNode.sh" script in /usr/lib/virtualbox
        _JUNEST_CMD -- cp /usr/share/virtualbox/VBoxCreateUSBNode.sh ./
        chmod a+x VBoxCreateUSBNode.sh
        $SUDOCMD mv VBoxCreateUSBNode.sh /usr/lib/virtualbox/
        $SUDOCMD chown -R root:vboxusers /usr/lib/virtualbox
    fi
    if ! test -f /etc/udev/rules.d/60-vboxusb.rules; then
        # Create the directory /etc/udev/rules.d
        $SUDOCMD mkdir -p /etc/udev/rules.d
        # Create and install the 60-vboxusb.rules file in /etc/udev/rules.d
        _JUNEST_CMD -- cp /etc/udev/rules.d/60-vboxusb.rules ./
        $SUDOCMD mv 60-vboxusb.rules /etc/udev/rules.d/
        # Reload the udev rules
        $SUDOCMD systemctl reload systemd-udevd
    fi
    printf "\nIt is recommended that you reboot for the changes to take effect.\n"
}

case "$1" in
'')
      _JUNEST_CMD -- /usr/bin/virtualbox
      ;;
'VirtualBoxVM')
      _JUNEST_CMD -- /usr/bin/VirtualBoxVM "$@"
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
'virtualbox'|*)
      _JUNEST_CMD -- /usr/bin/VirtualBox "$@"
      ;;
esac

HEREDOC
chmod a+x AppDir/AppRun

##########################################################################################################################################################
#	COMPILE
##########################################################################################################################################################

[ -f ./archimage-builder.sh ] && source ./archimage-builder.sh compile "$@"

##########################################################################################################################################################
#	CREATE THE APPIMAGE
##########################################################################################################################################################

if test -f ./*.AppImage; then rm -Rf ./*archimage*.AppImage; fi

APPNAME="VirtualBox-KVM"
REPO="VirtualBox-appimage"
TAG="latest"
UPINFO="gh-releases-zsync|$GITHUB_REPOSITORY_OWNER|$REPO|$TAG|*x86_64.AppImage.zsync"

echo "$vboxver" > ./version

_appimagetool() {
	if ! command -v appimagetool 1>/dev/null; then
		if [ ! -f ./appimagetool ]; then
			echo " Downloading appimagetool..." && curl -#Lo appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-"$ARCH".AppImage && chmod a+x ./appimagetool || exit 1
		fi
		./appimagetool "$@"
	else
		appimagetool "$@"
	fi
}

ARCH=x86_64 _appimagetool -u "$UPINFO" AppDir "$APPNAME"_"$vboxver"-"$ARCHIMAGE_VERSION"-x86_64.AppImage

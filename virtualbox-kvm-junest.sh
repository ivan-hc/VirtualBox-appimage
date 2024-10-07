#!/usr/bin/env bash

# NAME OF THE APP BY REPLACING "SAMPLE"
APP=virtualbox-kvm
BIN="virtualbox"
QTVER=$(curl -Ls https://gitlab.com/chaotic-aur/pkgbuilds/-/raw/main/virtualbox-kvm/PKGBUILD  | tr '"><' '\n' | sed "s/'/\n/g" | grep "^qt.*base$" | head -1)
[ "$QTVER" = qt5-base ] && kvantumver="kvantum-qt5 qt5ct qt5-svg kwindowsystem5" || kvantumver="kvantum qt6ct"
DEPENDENCES="ca-certificates alsa-lib alsa-plugins libpulse jack2 alsa-tools alsa-utils pipewire \
	libpng gnutls openal xorg-xwayland wayland xorg-server xorg-apps curl virtualbox-kvm v4l-utils \
	$kvantumver libva sdl2 vulkan-icd-loader numactl"
BASICSTUFF="binutils debugedit gzip"
COMPILERS="base-devel"
VERSION=$(curl -Ls https://gitlab.com/chaotic-aur/pkgbuilds/-/raw/main/virtualbox-kvm/PKGBUILD | grep vboxver | head -1 | tr "'" '\n' | grep "^[0-9]")

# CREATE AND ENTER THE APPDIR
if ! test -f ./appimagetool; then
	wget -q https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
	chmod a+x appimagetool
fi
mkdir -p "$APP".AppDir && cd "$APP".AppDir || exit 1

# SET APPDIR AS A TEMPORARY $HOME DIRECTORY
HOME="$(dirname "$(readlink -f $0)")"

# DOWNLOAD AND INSTALL JUNEST
function _enable_multilib() {
	printf "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> ./.junest/etc/pacman.conf
}

function _enable_chaoticaur() {
	# This function is ment to be used during the installation of JuNest, see "_pacman_patches"
	./.local/share/junest/bin/junest -- sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
	./.local/share/junest/bin/junest -- sudo pacman-key --lsign-key 3056513887B78AEB
	./.local/share/junest/bin/junest -- sudo pacman-key --populate chaotic
	./.local/share/junest/bin/junest -- sudo pacman --noconfirm -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
	printf "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >> ./.junest/etc/pacman.conf
}

function _custom_mirrorlist() {
	# This function is ment to be used during the installation of JuNest, see "_pacman_patches"
	COUNTRY=$(curl -i ipinfo.io | grep country | cut -c 15- | cut -c -2)
	rm -R ./.junest/etc/pacman.d/mirrorlist
	# Uncomment only one of the following two lines
	wget -q https://archlinux.org/mirrorlist/all/ -O - | awk NR==2 RS= | sed 's/#Server/Server/g' >> ./.junest/etc/pacman.d/mirrorlist # ENABLES WORLDWIDE MIRRORS
	#wget -q https://archlinux.org/mirrorlist/?country="$(echo $COUNTRY)" -O - | sed 's/#Server/Server/g' >> ./.junest/etc/pacman.d/mirrorlist # ENABLES MIRRORS OF YOUR COUNTY
}

function _bypass_signature_check_level() {
	sed -i 's/#SigLevel/SigLevel/g' ./.junest/etc/pacman.conf
	sed -i 's/Required DatabaseOptional/Never/g' ./.junest/etc/pacman.conf
}

function _pacman_patches() {
	_enable_multilib
	_enable_chaoticaur
	_custom_mirrorlist
	_bypass_signature_check_level
}

function _install_junest() {
	# Clone JuNest from upstream developer, at https://github.com/fsquillace/junest
	git clone https://github.com/fsquillace/junest.git ./.local/share/junest
	# Use the always updated junest-x86_64.tar.gz file from https://github.com/ivan-hc/junest
	if wget --version | head -1 | grep -q ' 1.'; then
		wget -q --show-progress https://github.com/ivan-hc/junest/releases/download/continuous/junest-x86_64.tar.gz
	else
		wget https://github.com/ivan-hc/junest/releases/download/continuous/junest-x86_64.tar.gz
	fi
	# Setup JuNest
	./.local/share/junest/bin/junest setup -i junest-x86_64.tar.gz
	rm -f junest-x86_64.tar.gz

	_pacman_patches

	# Update arch linux in junest
	./.local/share/junest/bin/junest -- sudo pacman -Syy
	./.local/share/junest/bin/junest -- sudo pacman --noconfirm -Syu
}

function _restore_junest() {
	cd ..
	echo "-------------------------------------"
	echo " RESTORATION OF BACKUPS IN PROGRESS"
	echo "-------------------------------------"
	echo ""
	rsync -av ./junest-backups/* ./"$APP".AppDir/.junest/ | echo "◆ Restore the content of the Arch Linux container, please wait"
	rsync -av ./stock-cache/* ./"$APP".AppDir/.cache/ | echo "◆ Restore the content of JuNest's ~/.cache directory"
	rsync -av ./stock-local/* ./"$APP".AppDir/.local/ | echo "◆ Restore the content of JuNest's ~/.local directory"
	echo ""
	echo "-----------------------------------------------------------"
	echo ""
	cd ./"$APP".AppDir || exit 1
}

if ! test -d "$HOME/.local/share/junest"; then
	_install_junest
else
	_restore_junest
fi

# INSTALL THE PROGRAM USING YAY
function _backup_junest() {
	cd ..
	echo ""
	echo "-----------------------------------------------------------"
	echo " BACKUP OF JUNEST FOR FURTHER APPIMAGE BUILDING ATTEMPTS"
	echo "-----------------------------------------------------------"
	mkdir -p ./junest-backups
	mkdir -p ./stock-cache
	mkdir -p ./stock-local
	echo ""
	rsync -av --ignore-existing ./"$APP".AppDir/.junest/* ./junest-backups/ | echo "◆ Backup the content of the Arch Linux container, please wait"
	rsync -av --ignore-existing ./"$APP".AppDir/.cache/* ./stock-cache/ | echo "◆ Backup the content of JuNest's ~/.cache directory"
	rsync -av --ignore-existing ./"$APP".AppDir/.local/* ./stock-local/ | echo "◆ Backup the content of JuNest's ~/.local directory"
	echo ""
	echo "-----------------------------------------------------------"
	echo ""
	cd ./"$APP".AppDir || exit 1
}

./.local/share/junest/bin/junest -- yay -Syy
./.local/share/junest/bin/junest -- gpg --keyserver keyserver.ubuntu.com --recv-key C01E1CAD5EA2C4F0B8E3571504C367C218ADD4FF # UNCOMMENT IF YOU USE THE AUR
if [ ! -z "$BASICSTUFF" ]; then
	./.local/share/junest/bin/junest -- yay --noconfirm -S "$BASICSTUFF"
fi
if [ ! -z "$COMPILERS" ]; then
	./.local/share/junest/bin/junest -- yay --noconfirm -S "$COMPILERS"
fi
if [ ! -z "$DEPENDENCES" ]; then
	./.local/share/junest/bin/junest -- yay --noconfirm -S "$DEPENDENCES"
fi
if [ ! -z "$APP" ]; then
	./.local/share/junest/bin/junest -- yay --noconfirm -S alsa-lib
	./.local/share/junest/bin/junest -- yay --noconfirm -S "$APP"
	./.local/share/junest/bin/junest -- glib-compile-schemas /usr/share/glib-2.0/schemas/
else
	echo "No app found, exiting"; exit 1
fi

_backup_junest

# PREPARE THE APPIMAGE
function _set_locale() {
	#sed "s/# /#>/g" ./.junest/etc/locale.gen | sed "s/#//g" | sed "s/>/#/g" >> ./locale.gen # UNCOMMENT TO ENABLE ALL THE LANGUAGES
	#sed "s/#$(echo $LANG)/$(echo $LANG)/g" ./.junest/etc/locale.gen >> ./locale.gen # ENABLE ONLY YOUR LANGUAGE, COMMENT IF YOU NEED MORE THAN ONE
	#rm ./.junest/etc/locale.gen
	#mv ./locale.gen ./.junest/etc/locale.gen
	rm ./.junest/etc/locale.conf
	#echo "LANG=$LANG" >> ./.junest/etc/locale.conf
	sed -i 's/LANG=${LANG:-C}/LANG=$LANG/g' ./.junest/etc/profile.d/locale.sh
	#./.local/share/junest/bin/junest -- sudo pacman --noconfirm -S glibc gzip
	#./.local/share/junest/bin/junest -- sudo locale-gen
}

function _add_launcher_and_icon() {
	rm -R -f ./*.desktop
	LAUNCHER=$(grep -iRl $BIN ./.junest/usr/share/applications/* | grep ".desktop" | head -1)
	cp -r "$LAUNCHER" ./
	if ! test -f ./*.png; then
		wget -q https://upload.wikimedia.org/wikipedia/commons/d/d5/Virtualbox_logo.png -O virtualbox.png
	fi

	# test if the desktop file and the icon are in the root of the future appimage (./*appdir/*)
	if test -f ./*.desktop; then
		echo ""
		echo "◆ The .desktop file is available in $APP.AppDir/"
		echo
	elif test -f ./.junest/usr/bin/"$BIN"; then
	 	echo ""
	 	echo "◆ No .desktop file available for $APP, creating a new one..."
	 	echo ""
	 	cat <<-HEREDOC >> ./"$APP".desktop
		[Desktop Entry]
		Version=1.0
		Type=Application
		Name=$(echo "$APP" | tr a-z A-Z)
		Comment=
		Exec=$BIN
		Icon=tux
		Categories=Utility;
		Terminal=true
		StartupNotify=true
		HEREDOC
		wget https://raw.githubusercontent.com/Portable-Linux-Apps/Portable-Linux-Apps.github.io/main/favicon.ico -O ./tux.png
	else
		echo "No binary in path... aborting all the processes."
		exit 0
	fi
}

function _create_AppRun() {
	rm -R -f ./AppRun
	cat <<-'HEREDOC' >> ./AppRun
	#!/bin/sh
	HERE="$(dirname "$(readlink -f $0)")"
	export UNION_PRELOAD=$HERE
	export JUNEST_HOME=$HERE/.junest
	export PATH=$PATH:$HERE/.local/share/junest/bin

	BINDS=" --dev-bind /dev /dev \
		--ro-bind /sys /sys \
		--bind-try /tmp /tmp \
		--proc /proc \
		--ro-bind-try /etc/resolv.conf /etc/resolv.conf \
		--ro-bind-try /etc/hosts /etc/hosts \
		--ro-bind-try /etc/nsswitch.conf /etc/nsswitch.conf \
		--ro-bind-try /etc/passwd /etc/passwd \
		--ro-bind-try /etc/group /etc/group \
		--ro-bind-try /etc/machine-id /etc/machine-id \
		--ro-bind-try /etc/asound.conf /etc/asound.conf \
		--ro-bind-try /etc/localtime /etc/localtime \
		--bind-try /media /media \
		--bind-try /mnt /mnt \
		--bind-try /opt /opt \
		--bind-try /usr/lib/locale /usr/lib/locale \
		--bind-try /usr/share/fonts /usr/share/fonts \
		--bind-try /usr/share/Kvantum /usr/share/Kvantum \
		--bind-try /usr/share/themes /usr/share/themes \
		--bind-try /var /var \
		"

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
			cp $JUNEST_HOME/usr/share/virtualbox/VBoxCreateUSBNode.sh ./
			chmod a+x VBoxCreateUSBNode.sh
			sudo mv VBoxCreateUSBNode.sh /usr/lib/virtualbox/
			sudo chown -R root:vboxusers /usr/lib/virtualbox
		fi
		if ! test -f /etc/udev/rules.d/60-vboxusb.rules; then
			# Create the directory /etc/udev/rules.d
			sudo mkdir -p /etc/udev/rules.d
			# Create and install the 60-vboxusb.rules file in /etc/udev/rules.d
			echo 'SUBSYSTEM=="usb_device", ACTION=="add", RUN+="/usr/lib/virtualbox/VBoxCreateUSBNode.sh $major $minor $attr{bDeviceClass}"' >> ./60-vboxusb.rules
			echo 'SUBSYSTEM=="usb", ACTION=="add", ENV{DEVTYPE}=="usb_device", RUN+="/usr/lib/virtualbox/VBoxCreateUSBNode.sh $major $minor $attr{bDeviceClass}"' >> ./60-vboxusb.rules
			echo 'SUBSYSTEM=="usb_device", ACTION=="remove", RUN+="/usr/lib/virtualbox/VBoxCreateUSBNode.sh --remove $major $minor"' >> ./60-vboxusb.rules
			echo 'SUBSYSTEM=="usb", ACTION=="remove", ENV{DEVTYPE}=="usb_device", RUN+="/usr/lib/virtualbox/VBoxCreateUSBNode.sh --remove $major $minor"' >> ./60-vboxusb.rules
			sudo mv 60-vboxusb.rules /etc/udev/rules.d/
			# Reload the udev rules
			sudo systemctl reload systemd-udevd
		fi
		printf "\nIt is recommended that you reboot for the changes to take effect.\n"
	}

	case "$1" in
	'')
		$HERE/.local/share/junest/bin/junest -n -b "$BINDS" -- virtualbox
		;;
	'VirtualBoxVM')
		$HERE/.local/share/junest/bin/junest -n -b "$BINDS" -- "$1" "$@"
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
	'virtualbox'|*) $HERE/.local/share/junest/bin/junest -n -b "$BINDS" -- VirtualBox "$@"
		;;
	esac | grep -v "You\|vboxdrv\|available for the current kernel\|Please recompile the kernel module\|sudo /sbin/vboxconfig" | cat -s
	HEREDOC
	chmod a+x ./AppRun
	sed -i "s/VERSION/$VERSION/g" ./AppRun
}

function _made_JuNest_a_potable_app() {
	# REMOVE "READ-ONLY FILE SYSTEM" ERRORS
	sed -i 's#${JUNEST_HOME}/usr/bin/junest_wrapper#${HOME}/.cache/junest_wrapper.old#g' ./.local/share/junest/lib/core/wrappers.sh
	sed -i 's/rm -f "${JUNEST_HOME}${bin_path}_wrappers/#rm -f "${JUNEST_HOME}${bin_path}_wrappers/g' ./.local/share/junest/lib/core/wrappers.sh
	sed -i 's/ln/#ln/g' ./.local/share/junest/lib/core/wrappers.sh
	sed -i 's#--bind "$HOME" "$HOME"#--bind-try /home /home --bind-try /run/user /run/user#g' .local/share/junest/lib/core/namespace.sh
	sed -i 's/rm -f "$file"/test -f "$file"/g' ./.local/share/junest/lib/core/wrappers.sh
}

function _remove_some_bloatwares() {
	echo Y | rm -R -f ./"$APP".AppDir/.cache/yay/*
	find ./"$APP".AppDir/.junest/usr/share/doc/* -not -iname "*$BIN*" -a -not -name "." -delete 2> /dev/null #REMOVE ALL DOCUMENTATION NOT RELATED TO THE APP
	find ./"$APP".AppDir/.junest/usr/share/locale/*/*/* -not -iname "*$BIN*" -a -not -name "." -delete 2> /dev/null #REMOVE ALL ADDITIONAL LOCALE FILES
	rm -R -f ./"$APP".AppDir/.junest/etc/makepkg.conf
	rm -R -f ./"$APP".AppDir/.junest/etc/pacman.conf
	rm -R -f ./"$APP".AppDir/.junest/usr/include #FILES RELATED TO THE COMPILER
	rm -R -f ./"$APP".AppDir/.junest/usr/man #APPIMAGES ARE NOT MENT TO HAVE MAN COMMAND
	rm -R -f ./"$APP".AppDir/.junest/var/* #REMOVE ALL PACKAGES DOWNLOADED WITH THE PACKAGE MANAGER
}

_set_locale
_add_launcher_and_icon
_create_AppRun
_made_JuNest_a_potable_app

cd .. || exit 1 # EXIT THE APPDIR

# EXTRACT PACKAGES
function _extract_main_package() {
	mkdir -p base
	rm -R -f ./base/*
	tar fx "$(find ./"$APP".AppDir -name "$APP-[0-9]*zst" | head -1)" -C ./base/
	#VERSION=$(cat ./base/.PKGINFO | grep pkgver | cut -c 10- | sed 's@.*:@@')
	mkdir -p deps
	rm -R -f ./deps/*
}

function _download_missing_packages() {
	localpackage=$(find ./"$APP".AppDir -name "$arg-[0-9]*zst")
	if ! test -f "$localpackage"; then
		./"$APP".AppDir/.local/share/junest/bin/junest -- yay --noconfirm -Sw "$arg"
	fi
}

function _extract_package() {
	_download_missing_packages &> /dev/null
	pkgname=$(find ./"$APP".AppDir -name "$arg-[0-9]*zst")
	if test -f "$pkgname"; then
		if ! grep -q "$(echo "$pkgname" | sed 's:.*/::')" ./packages 2>/dev/null;then
			echo "◆ Extracting $(echo "$pkgname" | sed 's:.*/::')"
			tar fx "$pkgname" -C ./deps/
			echo "$(echo "$pkgname" | sed 's:.*/::')" >> ./packages
		else
			tar fx "$pkgname" -C ./deps/
			echo "$(echo "$pkgname" | sed 's:.*/::')" >> ./packages
		fi
	fi
}

function _extract_all_dependences() {
	ARGS=$(echo "$DEPENDENCES" | tr " " "\n")
	for arg in $ARGS; do
		_extract_package
	 	cat ./deps/.PKGINFO 2>/dev/null | grep "depend = " | grep -v "makedepend = " | cut -c 10- | grep -v "=\|>\|<" > depdeps
	 	rm -f ./deps/.*
	done

	DEPS=$(cat ./base/.PKGINFO 2>/dev/null | grep "depend = " | grep -v "makedepend = " | cut -c 10- | grep -v "=\|>\|<")
	for arg in $DEPS; do
		_extract_package
	 	cat ./deps/.PKGINFO 2>/dev/null | grep "depend = " | grep -v "makedepend = " | cut -c 10- | grep -v "=\|>\|<" > depdeps
	 	rm -f ./deps/.*
	done

	DEPS2=$(cat ./depdeps 2>/dev/null | uniq)
	for arg in $DEPS2; do
		_extract_package
	 	cat ./deps/.PKGINFO 2>/dev/null | grep "depend = " | grep -v "makedepend = " | cut -c 10- | grep -v "=\|>\|<" > depdeps2
	 	rm -f ./deps/.*
	done

	DEPS3=$(cat ./depdeps2 2>/dev/null | uniq)
	for arg in $DEPS3; do
		_extract_package
	 	cat ./deps/.PKGINFO 2>/dev/null | grep "depend = " | grep -v "makedepend = " | cut -c 10- | grep -v "=\|>\|<" > depdeps3
	 	rm -f ./deps/.*
	done

	DEPS4=$(cat ./depdeps3 2>/dev/null | uniq)
	for arg in $DEPS4; do
		_extract_package
	 	cat ./deps/.PKGINFO 2>/dev/null | grep "depend = " | grep -v "makedepend = " | cut -c 10- | grep -v "=\|>\|<" > depdeps4
	 	rm -f ./deps/.*
	done

	rm -f ./packages
}

echo "-----------------------------------------------------------"
echo " EXTRACTING DEPENDENCES"
echo "-----------------------------------------------------------"
echo ""
_extract_main_package
_extract_all_dependences

# SAVE ESSENTIAL FILES AND LIBRARIES
echo ""
echo "-----------------------------------------------------------"
echo " IMPLEMENTING NECESSARY LIBRARIES (MAY TAKE SEVERAL MINUTES)"
echo "-----------------------------------------------------------"
echo ""

# SAVE FILES USING KEYWORDS
BINSAVED="certificates readlink kmod lsmod grep uname cat whoami gawk awk basename" # Enter here keywords to find and save in /usr/bin
SHARESAVED="certificates SAVESHAREPLEASE" # Enter here keywords or file/directory names to save in both /usr/share and /usr/lib
lib_browser_launcher="gio-launch-desktop libdl.so libpthread.so librt.so libasound.so libX11-xcb.so" # Libraries and files needed to launche the default browser
LIBSAVED="pk p11 alsa jack pipewire pulse libmpfr libGLX libxcb-res $lib_browser_launcher" # Enter here keywords or file/directory names to save in /usr/lib

# Save files in /usr/bin
function _savebins() {
	mkdir save
	mv ./"$APP".AppDir/.junest/usr/bin/*$BIN* ./save/
	mv ./"$APP".AppDir/.junest/usr/bin/bash ./save/
 	mv ./"$APP".AppDir/.junest/usr/bin/bwrap ./save/
	mv ./"$APP".AppDir/.junest/usr/bin/env ./save/
	mv ./"$APP".AppDir/.junest/usr/bin/sh ./save/
 	mv ./"$APP".AppDir/.junest/usr/bin/tr ./save/
   	mv ./"$APP".AppDir/.junest/usr/bin/tty ./save/
	for arg in $BINSAVED; do
		mv ./"$APP".AppDir/.junest/usr/bin/*"$arg"* ./save/
	done
	rm -R -f ./"$APP".AppDir/.junest/usr/bin/*
	mv ./save/* ./"$APP".AppDir/.junest/usr/bin/
	rmdir save
}

# Save files in /usr/lib
function _binlibs() {
	readelf -d ./"$APP".AppDir/.junest/usr/bin/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
	mv ./"$APP".AppDir/.junest/usr/lib/ld-linux-x86-64.so* ./save/
	mv ./"$APP".AppDir/.junest/usr/lib/*$APP* ./save/
	mv ./"$APP".AppDir/.junest/usr/lib/*$BIN* ./save/
	mv ./"$APP".AppDir/.junest/usr/lib/libdw* ./save/
	mv ./"$APP".AppDir/.junest/usr/lib/libelf* ./save/
	for arg in $SHARESAVED; do
		mv ./"$APP".AppDir/.junest/usr/lib/*"$arg"* ./save/
	done
	ARGS=$(tail -n +2 ./list | sort -u | uniq)
	for arg in $ARGS; do
		mv ./"$APP".AppDir/.junest/usr/lib/$arg* ./save/
		find ./"$APP".AppDir/.junest/usr/lib/ -name "$arg" -exec cp -r --parents -t save/ {} +
	done
	rm -R -f "$(find ./save/ | sort | grep ".AppDir" | head -1)"
	rm list
}

function _include_swrast_dri() {
	mkdir ./save/dri
	mv ./"$APP".AppDir/.junest/usr/lib/dri/swrast_dri.so ./save/dri/
}

function _libkeywords() {
	for arg in $LIBSAVED; do
		mv ./"$APP".AppDir/.junest/usr/lib/*"$arg"* ./save/
	done
}

function _readelf_save() {
	readelf -d ./save/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
	readelf -d ./save/*/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
	readelf -d ./save/*/*/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
	readelf -d ./save/*/*/*/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
	readelf -d ./save/*/*/*/*/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
	ARGS=$(tail -n +2 ./list | sort -u | uniq)
	for arg in $ARGS; do
		mv ./"$APP".AppDir/.junest/usr/lib/"$arg"* ./save/
		find ./"$APP".AppDir/.junest/usr/lib/ -name "$arg" -exec cp -r --parents -t save/ {} +
	done
	rsync -av ./save/"$APP".AppDir/.junest/usr/lib/* ./save/
 	rm -R -f "$(find ./save/ | sort | grep ".AppDir" | head -1)"
	rm list
}

function _readelf_base() {
	readelf -d ./base/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
	readelf -d ./base/*/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
	readelf -d ./base/*/*/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
	readelf -d ./base/*/*/*/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
	readelf -d ./base/*/*/*/*/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
}

function _readelf_deps() {
	readelf -d ./deps/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
	readelf -d ./deps/*/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
	readelf -d ./deps/*/*/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
	readelf -d ./deps/*/*/*/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
	readelf -d ./deps/*/*/*/*/* | grep .so | sed 's:.* ::' | cut -c 2- | sed 's/\(^.*so\).*$/\1/' | uniq >> ./list
}

function _liblibs() {
 	_readelf_base
  	_readelf_deps
	ARGS=$(tail -n +2 ./list | sort -u | uniq)
	for arg in $ARGS; do
		mv ./"$APP".AppDir/.junest/usr/lib/"$arg"* ./save/
		find ./"$APP".AppDir/.junest/usr/lib/ -name "$arg" -exec cp -r --parents -t save/ {} +
	done
	rsync -av ./save/"$APP".AppDir/.junest/usr/lib/* ./save/
 	rm -R -f "$(find ./save/ | sort | grep ".AppDir" | head -1)"
	rm list
	_readelf_save
	_readelf_save
	_readelf_save
	_readelf_save
}

function _mvlibs() {
	rm -R -f ./"$APP".AppDir/.junest/usr/lib/*
	mv ./save/* ./"$APP".AppDir/.junest/usr/lib/
}

function _savelibs() {
	mkdir save
	_binlibs 2> /dev/null
	#_include_swrast_dri 2> /dev/null
	_libkeywords 2> /dev/null
	_liblibs 2> /dev/null
	_mvlibs 2> /dev/null
	rmdir save
}

# Save files in /usr/share
function _saveshare() {
	mkdir save
	mv ./"$APP".AppDir/.junest/usr/share/*$APP* ./save/
 	mv ./"$APP".AppDir/.junest/usr/share/*$BIN* ./save/
	mv ./"$APP".AppDir/.junest/usr/share/fontconfig ./save/
	mv ./"$APP".AppDir/.junest/usr/share/glib-* ./save/
	mv ./"$APP".AppDir/.junest/usr/share/locale ./save/
	mv ./"$APP".AppDir/.junest/usr/share/mime ./save/
	mv ./"$APP".AppDir/.junest/usr/share/wayland ./save/
	mv ./"$APP".AppDir/.junest/usr/share/X11 ./save/
	for arg in $SHARESAVED; do
		mv ./"$APP".AppDir/.junest/usr/share/*"$arg"* ./save/
	done
	rm -R -f ./"$APP".AppDir/.junest/usr/share/*
	mv ./save/* ./"$APP".AppDir/.junest/usr/share/
 	rmdir save
}

_savebins 2> /dev/null
_savelibs
_saveshare 2> /dev/null

# ASSEMBLING THE APPIMAGE PACKAGE
function _rsync_main_package() {
	echo ""
	echo "-----------------------------------------------------------"
	rm -R -f ./base/.*
	rsync -av ./base/* ./"$APP".AppDir/.junest/ | echo "◆ Rsync the content of the \"$APP\" package"
}

function _rsync_dependences() {
	rm -R -f ./deps/.*
	rsync -av ./deps/* ./"$APP".AppDir/.junest/ | echo "◆ Rsync all dependeces, please wait..."
	echo "-----------------------------------------------------------"
	echo ""
}

function _remove_more_bloatwares() {
	_remove_some_bloatwares
 	rm -R -f ./"$APP".AppDir/.junest/home # remove the inbuilt home
	rm -R -f ./"$APP".AppDir/.junest/usr/lib/python*/__pycache__/* # if python is installed, removing this directory can save several megabytes
	#rm -R -f ./"$APP".AppDir/.junest/usr/lib/libLLVM* # included in the compilation phase, can sometimes be excluded for daily use
}

function _enable_mountpoints_for_the_inbuilt_bubblewrap() {
	mkdir -p ./"$APP".AppDir/.junest/home
	mkdir -p ./"$APP".AppDir/.junest/media
	mkdir -p ./"$APP".AppDir/.junest/usr/lib/locale
	mkdir -p ./"$APP".AppDir/.junest/usr/share/fonts
	mkdir -p ./"$APP".AppDir/.junest/usr/share/Kvantum
	mkdir -p ./"$APP".AppDir/.junest/usr/share/themes
	mkdir -p ./"$APP".AppDir/.junest/run/user
	rm -f ./"$APP".AppDir/.junest/etc/localtime && touch ./"$APP".AppDir/.junest/etc/localtime
	[ ! -f ./"$APP".AppDir/.junest/etc/asound.conf ] && touch ./"$APP".AppDir/.junest/etc/asound.conf
}

# ADDITIONAL STEPS
# Fix locale
if ! test -d ./"$APP".AppDir/.junest/usr/lib/"$APP"/nls; then
	mkdir -p mkdir -p ./"$APP".AppDir/.junest/usr/lib/virtualbox/nls
	rsync -av ./"$APP".AppDir/.junest/usr/share/virtualbox/nls/* ./"$APP".AppDir/.junest/usr/lib/virtualbox/nls/
fi
# Add guest additions
if ! test -f ./*.iso; then
	wget https://download.virtualbox.org/virtualbox/"${VERSION}"/VBoxGuestAdditions_"${VERSION}".iso -O ./VBoxGuestAdditions.iso || exit 1
	mkdir -p ./"$APP".AppDir/.junest/usr/lib/virtualbox/additions
	cp VBoxGuestAdditions.iso ./"$APP".AppDir/.junest/usr/lib/virtualbox/additions/ || exit 1
fi
# Add extension pack
if ! test -f ./Extension_Pack.tar; then
	wget https://download.virtualbox.org/virtualbox/"${VERSION}"/Oracle_VM_VirtualBox_Extension_Pack-"${VERSION}".vbox-extpack -O ./Extension_Pack.tar
	mkdir -p shrunk
	tar xfC ./Extension_Pack.tar shrunk
	rm -r shrunk/{darwin*,solaris*,win*}
	tar -c --gzip --file shrunk.vbox-extpack -C shrunk .
	install -Dm 644 shrunk.vbox-extpack ./"$APP".AppDir/.junest/usr/share/virtualbox/extensions/Oracle_VM_VirtualBox_Extension_Pack-"${VERSION}".vbox-extpack
	install -Dm 644 shrunk/ExtPack-license.txt ./"$APP".AppDir/.junest/usr/share/licenses/virtualbox-ext-oracle/PUEL
	mkdir -p ./"$APP".AppDir/.junest/usr/lib/virtualbox/ExtensionPacks/Oracle_VM_VirtualBox_Extension_Pack/linux.amd64
	install -Dm 644 shrunk/* ./"$APP".AppDir/.junest/usr/lib/virtualbox/ExtensionPacks/Oracle_VM_VirtualBox_Extension_Pack/
fi

_rsync_main_package
_rsync_dependences
_remove_more_bloatwares
strip --strip-debug ./$APP.AppDir/.junest/usr/lib/*
strip --strip-unneeded ./$APP.AppDir/.junest/usr/bin/*
_enable_mountpoints_for_the_inbuilt_bubblewrap

# CREATE THE APPIMAGE
if test -f ./*.AppImage; then
	rm -R -f ./*archimage*.AppImage
fi
[ -z "$GITHUB_REPOSITORY_OWNER" ] && GITHUB_REPOSITORY_OWNER="ivan-hc"
ARCH=x86_64 ./appimagetool --comp zstd --mksquashfs-opt -Xcompression-level --mksquashfs-opt 20 \
	-u "gh-releases-zsync|$GITHUB_REPOSITORY_OWNER|VirtualBox-appimage|continuous|*x86_64.AppImage.zsync" \
	./"$APP".AppDir "$(cat ./"$APP".AppDir/*.desktop | grep 'Name=' | head -1 | cut -c 6- | sed 's/ /-/g')"-KVM_"$VERSION"-archimage3.4.4-2-x86_64.AppImage

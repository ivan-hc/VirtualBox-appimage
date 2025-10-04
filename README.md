Unofficial AppImage of VirtualBox built on top of "JuNest" and formerly on "Conty", the portable Arch Linux containers that runs everywhere.

This AppImage includes Guest Additions ISO and the Extension Pack.

Oracle VM VirtualBox Extension Pack is released with PUEL license https://www.virtualbox.org/wiki/VirtualBox_PUEL

--------------------------------------------------
### NOTE: This wrapper is not verified by, affiliated with, or supported by Oracle.

**Part of the code is under a proprietary license and unofficially repackaged as an AppImage for demonstration purposes, for the original authors, to promote this packaging format to them. Consider this package as "experimental". I also invite you to request the authors to release an official AppImage, and if they agree, you can show this repository as a proof of concept.**

--------------------------------------------------

| ![Istantanea_2024-08-05_21-52-01 png](https://github.com/user-attachments/assets/2b3b9741-25bd-4f77-b753-6cd46762c567) | ![Istantanea_2024-08-05_21-55-33 png](https://github.com/user-attachments/assets/4b231fd4-555a-46eb-b22b-f84a174ddcd1) | ![Istantanea_2024-08-05_21-56-39 png](https://github.com/user-attachments/assets/cf5d1029-f1e6-427e-b3e6-54cbdf3e288f) |
| - | - | - |
| ![Istantanea_2024-08-05_21-58-45 png](https://github.com/user-attachments/assets/1346ef50-f524-4ee7-9134-454546865d6e) | ![Istantanea_2024-08-05_21-59-41 png](https://github.com/user-attachments/assets/cadb3c0b-6e64-4a95-ba19-aaac6f65f34d) | ![Istantanea_2024-08-06_17-17-21 png](https://github.com/user-attachments/assets/8ff8a8db-5b92-4e55-b4cd-5aaa191e204a) |

---------------------------------

### How it works

1. Download the AppImage from https://github.com/ivan-hc/VirtualBox-appimage/releases
2. Made it executable
```
chmod a+x ./*.AppImage
```
3. Run it
```
./*.AppImage
```
NOTE, if you use the Conty-based release, run the first time from terminal, since the internal "Conty" script may detect if you need Nvidia drivers for your GPU (this may need seconds before you can use VirtualBox). If you are an Nvidia user, for the JuNest-based build, hardware accelleration is provided by Conty. At first start it will install Nvidia drivers locally to allow the builtin Arch Linux container the use of hardware accelleration.

This AppImage does NOT require libfuse2, being it a new generation one.

Also, this VirtualBox AppImage does not require "vboxdrv", being it based on VirtualBox KVM.

---------------------------------

### USB support

According with [this guide](https://github.com/cyberus-technology/virtualbox-kvm#usb-pass-through), to enable the USB support **we need to handle some files using root permissions**:
1. we need to add the "VBoxCreateUSBNode.sh" of VirtualBox into a /usr/lib/virtualbox directory on the host
2. we need to create the "vboxusers" group and add our $USER in that group
3. we need to add the "60-vboxusb.rules" file to /etc/udev/rules.d and then we need to reload these rules

I have resumed all these steps into one function available in the AppRun script of the AppImage, name of the function is "VBoxUSB_enable".

To enable the USB support you must run the following command:
```
./*.AppImage --vbox-usb-enable
```
this is the message that will appear, you need to enter the "sudo" password
![Istantanea_2024-08-09_21-29-31](https://github.com/user-attachments/assets/8781e646-d151-4ddd-a61b-974284a3e780)

Alternativelly you can follow the guide at https://github.com/cyberus-technology/virtualbox-kvm#usb-pass-through and enable the USB support manually.

NOTE: the function above extracts the "VBoxCreateUSBNode.sh" from the internal Arch Linux container, if you want to do it manually, you can download any VirtualBox package and check for "VBoxCreateUSBNode.sh" and made it executable. You can also extract it from the AppImage when it is mounted, in /tmp, and from builds based on JuNest its enough to extract the AppImage with `--appimage-extract` and get the script from squashfs-root/.junest/usr/share/virtualbox.

See also https://github.com/ivan-hc/VirtualBox-appimage/issues/7

---------------------------------

### How to build the JuNest-based AppImage

The latest releases are based on [JuNest](https://github.com/fsquillace/junest), it is enough tu follow the instructions on the README of the "Archimage" project, at https://github.com/ivan-hc/ArchImage and run the script https://github.com/ivan-hc/VirtualBox-appimage/blob/main/virtualbox-kvm-junest.sh into a dedicated new directory. No root permissions are needed.

---------------------------------

### How to build the Conty-based AppImage

The Conty-based AppImage contains the following structure:
```
|---- AppRun
|---- virtualbox.desktop
|---- virtualbox.svg
|---- conty.sh
```
1. The AppRun is the core script of the AppImage
2. The .desktop file of Virtualbox
3. The icon of Virtualbox
4. The Arch Linux container named "conty.sh", it contains Virtualbox KVM.

Points 1, 2 and 3 are the essential elements of any AppImage.

The script "conty.sh" (4) is the big one among the elements of this AppImage.

This is what each file of my workflow is ment for:
1. [create-arch-bootstrap.sh](https://github.com/ivan-hc/VirtualBox-appimage/blob/main/create-arch-bootstrap.sh) creates an Arch Linux chroot, where VirtualBox KVM is installed from ChaoticAUR. This is the first script to be used ("root" required);
2. [create-conty.sh](https://github.com/ivan-hc/Conty/blob/master/create-conty.sh) is the second script used in this process, it converts the Arch Linux chroot created by "create-arch-bootstrap.sh" into a big script named "conty.sh", that includes "conty-start.sh";
3. [conty-start.sh](https://github.com/ivan-hc/Conty/blob/master/conty-start.sh) is the script responsible of startup inizialization processes to made Conty work. It includes a function that detects the version of the Nvidia drivers needed, if they are needed, the script downloads and installs them in ~/.local/share/Conty. Also it is responsible of full integration of Conty with the host system, using "bubblewrap;
4. [utils_dwarfs.tar.gz](https://github.com/ivan-hc/Conty/releases/download/utils/utils_dwarfs.tar.gz) contains "dwarfs", a set of tools similar to squashfs to compress filesystems, and it is needed to compress "conty.sh" as much as possible;
5. [virtualbox-conty-builder.sh](https://github.com/ivan-hc/VirtualBox-appimage/blob/main/virtualbox-conty-builder.sh) is a script i wrote to pundle "conty.sh" near the AppRun, the .desktop file and the icon to convert everything into an AppImage. It is ment to be used in github actions.

Files 1, 2, 3 and 4 come from my fork of https://github.com/Kron4ek/Conty

Files 1, 2 and 3 are a mod of the original ones to made them smaller and with only what its needed to made VirtualBox work.

To learn more about "Conty", to download more complete builds or to learn more on how to create your own, visit the official repository of the project:

https://github.com/Kron4ek/Conty
--------------

---------------------------------

## Known issues

### ◆ Shortcuts
If you right-click on the VM to createa launcher, open the .desktop file and change the "Exec=" entry from
```
Exec=/usr/lib/virtualbox/VirtualBoxVM --comment ...
```
to
```
Exec=/path/to/VirtualBox-{VERSION}-x86_64.AppImage VirtualBoxVM --comment ...
```
or if you use "AM" or "AppMan" (see below)
```
Exec=virtualbox VirtualBoxVM --comment ...
```

---------------------------------

## Credits

- JuNest https://github.com/fsquillace/junest
- Archimage https://github.com/ivan-hc/ArchImage
- Conty https://github.com/Kron4ek/Conty
- VirtualBox KVM team https://github.com/cyberus-technology/virtualbox-kvm
- ChaoticAUR team https://aur.chaotic.cx

------------------------------------------------------------------------

## Install and update it with ease

### *"*AM*" Application Manager* 
#### *Package manager, database & solutions for all AppImages and portable apps for GNU/Linux!*

[![sample.png](https://raw.githubusercontent.com/ivan-hc/AM/main/sample/sample.png)](https://github.com/ivan-hc/AM)

[![Readme](https://img.shields.io/github/stars/ivan-hc/AM?label=%E2%AD%90&style=for-the-badge)](https://github.com/ivan-hc/AM/stargazers) [![Readme](https://img.shields.io/github/license/ivan-hc/AM?label=&style=for-the-badge)](https://github.com/ivan-hc/AM/blob/main/LICENSE)

*"AM"/"AppMan" is a set of scripts and modules for installing, updating, and managing AppImage packages and other portable formats, in the same way that APT manages DEBs packages, DNF the RPMs, and so on... using a large database of Shell scripts inspired by the Arch User Repository, each dedicated to an app or set of applications.*

*The engine of "AM"/"AppMan" is the "APP-MANAGER" script which, depending on how you install or rename it, allows you to install apps system-wide (for a single system administrator) or locally (for each user).*

*"AM"/"AppMan" aims to be the default package manager for all AppImage packages, giving them a home to stay.*

*You can consult the entire **list of managed apps** at [**portable-linux-apps.github.io/apps**](https://portable-linux-apps.github.io/apps).*

## *Go to *https://github.com/ivan-hc/AM* for more!*

------------------------------------------------------------------------

| [***Install "AM"***](https://github.com/ivan-hc/AM) | [***See all available apps***](https://portable-linux-apps.github.io) | [***Support me on ko-fi.com***](https://ko-fi.com/IvanAlexHC) | [***Support me on PayPal.me***](https://paypal.me/IvanAlexHC) |
| - | - | - | - |

------------------------------------------------------------------------

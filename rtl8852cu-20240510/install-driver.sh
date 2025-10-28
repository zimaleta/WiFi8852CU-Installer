#!/bin/sh

# Purpose: Install Realtek out-of-kernel USB WiFi adapter drivers.
#
# Supports dkms and non-dkms installations.
#
# To make this file executable:
#
# $ chmod +x install-driver.sh
#
# To execute this file:
#
# $ sudo ./install-driver.sh
#
# or
#
# $ sudo sh install-driver.sh
#
# Note: It is common for Realtek out-of-kernel drivers to have many
# source files set to executable. This can cause problems in some
# situations. To remove executable from files only, run the following
# in the subdirectories:
#
# Warning: Do not run the following in the directory that contains the
# script files as they need to be executable!
#
# find . -type f -exec chmod -x {} \;
#
# To check for errors and to check that this script does not require bash:
#
# $ shellcheck install-driver.sh
#
# Copyright(c) 2025 Nick Morrow
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.

SCRIPT_NAME="install-driver.sh"
SCRIPT_VERSION="20250317"

MODULE_NAME="8852cu"

DRV_NAME="rtl8852cu"
DRV_VERSION="1.19.2.1"
DRV_DIR="$(pwd)"

OPTIONS_FILE="${MODULE_NAME}.conf"

KARCH="$(uname -m)"
#if [ -z "${KARCH+1}" ]; then
#	KARCH="$(uname -m)"
#fi

KVER="$(uname -r)"
#if [ -z "${KVER+1}" ]; then
#	KVER="$(uname -r)"
#fi

MODDESTDIR="/lib/modules/${KVER}/kernel/drivers/net/wireless/"

# detemine what ARCH will be sent to gcc
#GARCH="$(uname -m | sed -e "s/i.86/i386/; s/ppc/powerpc/; s/armv.l/arm/; s/aarch64/arm64/; s/riscv.*/riscv/;")"
#if [ -z "${GARCH+1}" ]; then
#	GARCH="$(uname -m | sed -e "s/i.86/i386/; s/ppc/powerpc/; s/armv.l/arm/; s/aarch64/arm64/; s/riscv.*/riscv/;")"
#fi

# check to ensure sudo or su - was used to start the script
if [ "$(id -u)" -ne 0 ]; then
	echo "You must run this script with superuser (root) privileges."
	echo "Try: \"sudo ./${SCRIPT_NAME}\""
	exit 1
fi

# support for the NoPrompt option allows non-interactive use of this script
NO_PROMPT=0
# get the script options
while [ $# -gt 0 ]
do
	case $1 in
		NoPrompt)
			NO_PROMPT=1 ;;
		*h|*help|*)
			echo "Syntax $0 <NoPrompt>"
			echo "       NoPrompt - noninteractive mode"
			echo "       -h|--help - Show help"
			exit 1
			;;
	esac
	shift
done

# set default editor
DEFAULT_EDITOR="$(cat default-editor.txt)"
# try to find the user's default text editor through the EDITORS_SEARCH array
for TEXT_EDITOR in "${VISUAL}" "${EDITOR}" "${DEFAULT_EDITOR}" vi; do
	command -v "${TEXT_EDITOR}" >/dev/null 2>&1 && break
done
# fail if no editor was found
if ! command -v "${TEXT_EDITOR}" >/dev/null 2>&1; then
	echo "No text editor found (default: ${DEFAULT_EDITOR})."
	echo "Please install ${DEFAULT_EDITOR} or edit the file 'default-editor.txt' to specify your editor."
	echo "Once complete, please run \"sudo ./${SCRIPT_NAME}\""
	exit 1
fi

# check to ensure gcc is installed
if ! command -v gcc >/dev/null 2>&1; then
	echo "A required package is not installed."
	echo "Please install the following package: gcc"
	echo "Once the package is installed, please run \"sudo ./${SCRIPT_NAME}\""
	exit 1
fi

# ensure /usr/sbin is in the PATH so iw can be found
if ! echo "$PATH" | grep -qw sbin; then
        export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fi

# check to ensure iw is installed
if ! command -v iw >/dev/null 2>&1; then
	echo "A required package is not installed."
	echo "Please install the following package: iw"
	echo "Once the package is installed, please run \"sudo ./${SCRIPT_NAME}\""
	exit 1
fi

# if NoPrompt is not used, display notice then ask if ready to continue
if [ $NO_PROMPT -ne 1 ]; then
	echo "-----------------------------------------------------------------"
	echo "Please copy and post all displayed lines when reporting an issue!"
	echo "-----------------------------------------------------------------"
	printf "Press Enter to continue..."
	read -r yn
	case "$yn" in
#		[nN]) exit ;;
#		*) clear ;;
		*) ;;
	esac
	echo
fi

# displays script name and version
echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"

# display distro info
lsb_release -id | grep D

# display kernel version
echo "Kernel version: ${KVER}"

# display kernel parameters
sed 's/root=[^ ]*//;s/[ ]\+/, /g;s/^BOOT_IMAGE=[^ ]*/Parameters:/' /proc/cmdline

# display kernel architecture
echo "Kernel ARCH: ${KARCH}"

# display architecture to send to gcc
#echo ": ${GARCH} (architecture to send to gcc)"

SMEM=$(LC_ALL=C free | awk '/Mem:/ { print $2 }')
sproc=$(nproc)
# avoid Out of Memory condition in low-RAM systems by limiting core usage
if [ "$sproc" -gt 1 ]; then
	if [ "$SMEM" -lt 1400000 ]
	then
		sproc=2
	fi
	if [ "$SMEM" -lt 700000 ]
	then
		sproc=1
	fi
fi

# display number of in-use processing units / total processing units
echo "Processing units: ${sproc}/$(nproc) (in-use/total)"

# display total system memory
echo "Memory: ${SMEM}"

# display gcc version
gcc_ver=$(gcc --version | grep -i gcc)
echo "gcc: ""${gcc_ver}"

# display version of gcc used to compile the kernel
#gcc_ver_used_to_compile_the_kernel=$(cat /proc/version | sed 's/^.*gcc/gcc/' | sed 's/\s.*$//')
#if [ "${gcc_ver_used_to_compile_the_kernel}" ]; then
#	echo "gcc: ""${gcc_ver_used_to_compile_the_kernel} (version used to compile the kernel)"
#fi

# display dkms version if installed
if command -v dkms >/dev/null 2>&1; then
	dkms_ver=$(dkms --version)
	echo "dkms: ""${dkms_ver}"
fi

# display Secure Boot status
if command -v mokutil >/dev/null 2>&1; then
	case $(mokutil --sb-state 2>&1) in
		*enabled*) echo "Secure Boot: enabled" ;;
		*disabled*) echo "Secure Boot: disabled" ;;
		*) echo "Secure Boot: not supported" ;;
	esac
else
	echo "Secure Boot: mokutil not installed (status unknown)"
fi

# display if VM detected
dmesg | grep -i hypervisor
# the following is not working well
#if command -v dmesg >/dev/null 2>&1; then
#	VM_detected=""
#	VM_detected=(dmesg | grep -i hypervisor)
#	if [ -z "$VM_detected" ]; then
#		echo "Virtual Machine: not detected"
#	else
#		echo "Virtual Machine: detected"
#	fi
#fi

# get country code
# display result of `iw reg get`
# https://docs.kernel.org/networking/regulatory.html
# https://www.marcusfolkesson.se/blog/linux-wireless-regulatory/
#if command -v iw >/dev/null 2>&1; then
#	echo ": Linux Wireless Regulatory Settings:"
#	iw reg get | grep -i 'global\|country\|phy#'
iw reg get | grep country
#	echo ": Info: https://docs.kernel.org/networking/regulatory.html"
#	echo ": Info: https://www.marcusfolkesson.se/blog/linux-wireless-regulatory/"
#fi

# possible future additions
#lsusb
#rfkill list all
#dkms status


echo


# check to ensure bc is installed
if ! command -v bc >/dev/null 2>&1; then
	echo "A required package is not installed."
	echo "Please install the following package: bc"
	echo "Once the package is installed, please run \"sudo ./${SCRIPT_NAME}\""
	exit 1
fi

# check to ensure make is installed
if ! command -v make >/dev/null 2>&1; then
	echo "A required package is not installed."
	echo "Please install the following package: make"
	echo "Once the package is installed, please run \"sudo ./${SCRIPT_NAME}\""
	exit 1
fi

# check to see if the correct header files are installed
# - problem with fedora 40 reported
if [ ! -d "/lib/modules/$(uname -r)/build" ]; then
	echo "Your kernel header files aren't properly installed."
	echo "Please consult your distro documentation or user support forums."
	echo "Once the header files are properly installed, please run \"sudo ./${SCRIPT_NAME}\""
	exit 1
fi

# check to ensure rfkill is installed
#if ! command -v rfkill >/dev/null 2>&1; then
#	echo "A required package is not installed."
#	echo "Please install the following package: rfkill"
#	echo "Once the package is installed, please run \"sudo ./${SCRIPT_NAME}\""
#	exit 1
#fi


echo "Checking for previously installed drivers..."

# check for and uninstall non-dkms installations
# standard naming
if [ -f "${MODDESTDIR}${MODULE_NAME}.ko" ]; then
	echo "Uninstalling a non-dkms installation:"
	echo "${MODDESTDIR}${MODULE_NAME}.ko"
	rm -f "${MODDESTDIR}"${MODULE_NAME}.ko
	/sbin/depmod -a "${KVER}"
	echo "Deleting ${OPTIONS_FILE} from /etc/modprobe.d"
	rm -f /etc/modprobe.d/${OPTIONS_FILE}
	echo "Deleting source files from /usr/src/${DRV_NAME}-${DRV_VERSION}"
	rm -rf /usr/src/${DRV_NAME}-${DRV_VERSION}
	make clean >/dev/null 2>&1
fi


# check for and uninstall non-dkms installations
# with rtl added to module name (PClinuxOS)
# Dear PCLinuxOS devs, the driver name uses rtl, the module name does not.
if [ -f "${MODDESTDIR}rtl${MODULE_NAME}.ko" ]; then
	echo "Uninstalling a non-dkms installation:"
	echo "${MODDESTDIR}rtl${MODULE_NAME}.ko"
	rm -f "${MODDESTDIR}"rtl${MODULE_NAME}.ko
	/sbin/depmod -a "${KVER}"
	echo "Deleting ${OPTIONS_FILE} from /etc/modprobe.d"
	rm -f /etc/modprobe.d/${OPTIONS_FILE}
	echo "Deleting source files from /usr/src/${DRV_NAME}-${DRV_VERSION}"
	rm -rf /usr/src/${DRV_NAME}-${DRV_VERSION}
	make clean >/dev/null 2>&1
fi


# check for and uninstall non-dkms installations
# with module in a unique non-standard location (Armbian)
# Example: /usr/lib/modules/5.15.80-rockchip64/kernel/drivers/net/wireless/rtl8821cu/8821cu.ko.xz
if [ -f "/usr/lib/modules/${KVER}/kernel/drivers/net/wireless/${DRV_NAME}/${MODULE_NAME}.ko.xz" ]; then
	echo "Uninstalling a non-dkms installation:"
	echo "/usr/lib/modules/${KVER}/kernel/drivers/net/wireless/${DRV_NAME}/${MODULE_NAME}.ko.xz"
	rm -f /usr/lib/modules/"${KVER}"/kernel/drivers/net/wireless/${DRV_NAME}/${MODULE_NAME}.ko.xz
	/sbin/depmod -a "${KVER}"
	echo "Deleting ${OPTIONS_FILE} from /etc/modprobe.d"
	rm -f /etc/modprobe.d/${OPTIONS_FILE}
	echo "Deleting source files from /usr/src/${DRV_NAME}-${DRV_VERSION}"
	rm -rf /usr/src/${DRV_NAME}-${DRV_VERSION}
	make clean >/dev/null 2>&1
fi


# check for and uninstall dkms installations
if command -v dkms >/dev/null 2>&1; then
	dkms status | while IFS="/,: " read -r drvname drvver kerver _dummy; do
		case "$drvname" in *${MODULE_NAME})
			if [ "${kerver}" = "added" ]; then
				echo "Uninstalling a driver that was added to dkms."
				dkms remove -m "${drvname}" -v "${drvver}" --all
			else
				echo "Uninstalling a driver that was installed by dkms."
				dkms remove -m "${drvname}" -v "${drvver}" -k "${kerver}" -c "/usr/src/${drvname}-${drvver}/dkms.conf"
			fi
		esac
	done
	if [ -f /etc/modprobe.d/${OPTIONS_FILE} ]; then
		echo "Deleting ${OPTIONS_FILE} from /etc/modprobe.d"
		rm /etc/modprobe.d/${OPTIONS_FILE}
	fi
	if [ -d /usr/src/${DRV_NAME}-${DRV_VERSION} ]; then
		echo "Deleting source files from /usr/src/${DRV_NAME}-${DRV_VERSION}"
		rm -r /usr/src/${DRV_NAME}-${DRV_VERSION}
	fi
fi


echo "Finished checking for and uninstalling previously installed drivers."


echo


#echo "Updating driver."
#git pull
echo "Starting installation:"
echo "Copying ${OPTIONS_FILE} to /etc/modprobe.d"
cp -f ${OPTIONS_FILE} /etc/modprobe.d


# determine if dkms is installed and run the appropriate installation routines
if ! command -v dkms >/dev/null 2>&1; then
	echo "The non-dkms installation routines are in use."

	make clean >/dev/null 2>&1

	make -j"${sproc}"
	RESULT=$?

	if [ "$RESULT" != "0" ]; then
		echo "An error occurred:  ${RESULT}"
		echo "Please report this error."
		echo "Please copy and post the following items into the problem report."
		echo "    -all screen output from install-driver.sh"
		echo "    -the contents of make.log as mentioned 3 lines above"
		echo "You should run the following before reattempting installation."
		echo "$ sudo ./uninstall-driver.sh"
		exit $RESULT
	fi


#	if secure boot is active, use sign-install
	if command -v mokutil >/dev/null 2>&1; then
		if mokutil --sb-state | grep -i  enabled >/dev/null 2>&1; then
			echo ": SecureBoot enabled - read FAQ about SecureBoot"
			make sign-install
			RESULT=$?
		else
			make install
			RESULT=$?		
		fi
	else
		make install
		RESULT=$?
	fi
	
	if [ "$RESULT" = "0" ]; then
        	make clean >/dev/null 2>&1
		echo "The driver was installed successfully."
		echo
	else
		echo "An error occurred:  ${RESULT}"
		echo "Please report this error."
		echo "Please copy and post the following items into the problem report."
		echo "    -all screen output from install-driver.sh"
		echo "    -the contents of make.log as mentioned 3 lines above"
		echo "You should run the following before reattempting installation."
		echo "$ sudo ./uninstall-driver.sh"
		exit $RESULT
	fi
else
	echo "The dkms installation routines are in use."


# 	the dkms add command requires source in /usr/src/${DRV_NAME}-${DRV_VERSION}
	echo "Copying source files to /usr/src/${DRV_NAME}-${DRV_VERSION}"
	cp -r "${DRV_DIR}" /usr/src/${DRV_NAME}-${DRV_VERSION}


# run dkms add
	dkms add -m ${DRV_NAME} -v ${DRV_VERSION} -k "${KVER}" -c "/usr/src/${DRV_NAME}-${DRV_VERSION}/dkms.conf"
#	dkms add -m ${DRV_NAME} -v ${DRV_VERSION} -k "${KVER/${KARCH}}" -c "/usr/src/${DRV_NAME}-${DRV_VERSION}/dkms.conf"
	RESULT=$?

#	RESULT will be 3 if the DKMS tree already contains the same module/version
#	combo. You cannot add the same module/version combo more than once.
	if [ "$RESULT" != "0" ]; then
		if [ "$RESULT" = "3" ]; then
			echo "This driver may already be installed."
			echo "Run the following and then reattempt installation."
			echo "$ sudo ./uninstall-driver.sh"
			exit $RESULT
		else
		echo "An error occurred:  ${RESULT}"
		echo "Please report this error."
		echo "Please copy and post the following items into the problem report."
		echo "    -all screen output from install-driver.sh"
		echo "    -the contents of make.log as mentioned 3 lines above"
		echo "You should run the following before reattempting installation."
		echo "$ sudo ./uninstall-driver.sh"
		exit $RESULT
		fi
	else
		echo "The driver was added to dkms successfully."
		echo
	fi


# run dkms build
	if command -v /usr/bin/time >/dev/null 2>&1; then
		/usr/bin/time -f "Compile time: %U seconds" dkms build -m ${DRV_NAME} -v ${DRV_VERSION} -k "${KVER}" -c "/usr/src/${DRV_NAME}-${DRV_VERSION}/dkms.conf" --force
#		/usr/bin/time -f "Compile time: %U seconds" dkms build -m ${DRV_NAME} -v ${DRV_VERSION} -k "${KVER}/${KARCH}" -c "/usr/src/${DRV_NAME}-${DRV_VERSION}/dkms.conf" --force
	else
		dkms build -m ${DRV_NAME} -v ${DRV_VERSION} -k "${KVER}" -c "/usr/src/${DRV_NAME}-${DRV_VERSION}/dkms.conf" --force
#		dkms build -m ${DRV_NAME} -v ${DRV_VERSION} -k "${KVER}/${KARCH}" -c "/usr/src/${DRV_NAME}-${DRV_VERSION}/dkms.conf" --force
	fi
	RESULT=$?

	if [ "$RESULT" != "0" ]; then
		echo "An error occurred:  ${RESULT}"
		echo "Please report this error."
		echo "Please copy and post the following items into the problem report."
		echo "    -all screen output from install-driver.sh"
		echo "    -the contents of make.log as mentioned 3 lines above"
		echo "You should run the following before reattempting installation."
		echo "$ sudo ./uninstall-driver.sh"
		exit $RESULT
	else
		echo "The driver was built by dkms successfully."
	fi


# run dkms install
	dkms install -m ${DRV_NAME} -v ${DRV_VERSION} -k "${KVER}" -c "/usr/src/${DRV_NAME}-${DRV_VERSION}/dkms.conf" --force
#	dkms install -m ${DRV_NAME} -v ${DRV_VERSION} -k "${KVER}/${KARCH}" -c "/usr/src/${DRV_NAME}-${DRV_VERSION}/dkms.conf" --force
	RESULT=$?

	if [ "$RESULT" != "0" ]; then
		echo "An error occurred:  ${RESULT}"
		echo "Please report this error."
		echo "Please copy and post the following items into the problem report."
		echo "    -all screen output from install-driver.sh"
		echo "    -the contents of make.log as mentioned 3 lines above"
		echo "You should run the following before reattempting installation."
		echo "$ sudo ./uninstall-driver.sh"
		exit $RESULT
	else
		echo "The driver was installed by dkms successfully."
		echo
	fi
fi


# provide driver upgrade information
echo "Info: Update this driver with the following commands as needed:"
echo
echo "$ git pull"
echo "$ sudo sh install-driver.sh"
echo
echo "Note: Updates to this driver SHOULD be performed before distro"
echo "      upgrades such as Ubuntu 23.10 to 24.04."
echo "Note: Updates to this driver SHOULD be performed before kernel"
echo "      upgrades such as kernel 6.5 to 6.6."
echo "Note: Updates can be performed as often as you like. It is"
echo "      recommended to update at least every 3 months."
echo "Note: Work on this driver, like the Linux kernel, is continuous."
echo
echo "Enjoy!"
echo


# unblock wifi
if command -v rfkill >/dev/null 2>&1; then
	rfkill unblock wlan
else
	echo "Unable to run $ rfkill unblock wlan"
fi


# if NoPrompt is not used, ask user some questions
if [ $NO_PROMPT -ne 1 ]; then
	printf "Do you want to edit the driver options file now? (recommended) [Y/n] "
	read -r yn
	case "$yn" in
		[nN]) ;;
		*) ${TEXT_EDITOR} /etc/modprobe.d/${OPTIONS_FILE} ;;
	esac

	printf "Do you want to apply the new options by rebooting now? (recommended) [Y/n] "
	read -r yn
	case "$yn" in
		[nN]) ;;
		*) reboot ;;
	esac
fi

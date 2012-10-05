# Common code for generating core reference images
#
# Copyright (C) 2007-2011 Linux Foundation

LIC_FILES_CHKSUM = "file://${COREBASE}/LICENSE;md5=3f40d7994397109285ec7b81fdeb3b58 \
                    file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

# IMAGE_FEATURES control content of the core reference images
# 
# By default we install packagegroup-core-boot and packagegroup-base packages - this gives us
# working (console only) rootfs.
#
# Available IMAGE_FEATURES:
#
# - x11                 - X server
# - x11-base            - X server with minimal environment
# - x11-sato            - OpenedHand Sato environment
# - tools-debug         - debugging tools
# - tools-profile       - profiling tools
# - tools-testapps      - tools usable to make some device tests
# - tools-sdk           - SDK (C/C++ compiler, autotools, etc.)
# - nfs-server          - NFS server
# - ssh-server-dropbear - SSH server (dropbear)
# - ssh-server-openssh  - SSH server (openssh)
# - qt4-pkgs            - Qt4/X11 and demo applications
# - package-management  - installs package management tools and preserves the package manager database
# - debug-tweaks        - makes an image suitable for development, e.g. allowing passwordless root logins
# - dev-pkgs            - development packages (headers, etc.) for all installed packages in the rootfs
# - dbg-pkgs            - debug symbol packages for all installed packages in the rootfs
# - doc-pkgs            - documentation packages for all installed packages in the rootfs
#
PACKAGE_GROUP_x11 = "packagegroup-core-x11"
PACKAGE_GROUP_x11-base = "packagegroup-core-x11-base"
PACKAGE_GROUP_x11-sato = "packagegroup-core-x11-sato"
PACKAGE_GROUP_tools-debug = "packagegroup-core-tools-debug"
PACKAGE_GROUP_tools-profile = "packagegroup-core-tools-profile"
PACKAGE_GROUP_tools-testapps = "packagegroup-core-tools-testapps"
PACKAGE_GROUP_tools-sdk = "packagegroup-core-sdk packagegroup-core-standalone-sdk-target"
PACKAGE_GROUP_nfs-server = "packagegroup-core-nfs-server"
PACKAGE_GROUP_ssh-server-dropbear = "packagegroup-core-ssh-dropbear"
PACKAGE_GROUP_ssh-server-openssh = "packagegroup-core-ssh-openssh"
PACKAGE_GROUP_package-management = "${ROOTFS_PKGMANAGE}"
PACKAGE_GROUP_qt4-pkgs = "packagegroup-core-qt-demoapps"


# IMAGE_FEATURES_REPLACES_foo = 'bar1 bar2'
# Including image feature foo would replace the image features bar1 and bar2
IMAGE_FEATURES_REPLACES_ssh-server-openssh = "ssh-server-dropbear"

# IMAGE_FEATURES_CONFLICTS_foo = 'bar1 bar2'
# An error exception would be raised if both image features foo and bar1(or bar2) are included

python __anonymous() {
    # Ensure we still have a splash screen for existing images
    if base_contains("IMAGE_FEATURES", "apps-console-core", "1", "", d) == "1":
        bb.warn("%s: apps-console-core in IMAGE_FEATURES is no longer supported; adding \"splash\" to enable splash screen" % d.getVar("PN", True))
        d.appendVar("IMAGE_FEATURES", " splash")
}


CORE_IMAGE_BASE_INSTALL = '\
    packagegroup-core-boot \
    packagegroup-base-extended \
    \
    ${CORE_IMAGE_EXTRA_INSTALL} \
    '

CORE_IMAGE_EXTRA_INSTALL ?= ""

IMAGE_INSTALL ?= "${CORE_IMAGE_BASE_INSTALL}"

inherit image

# Create /etc/timestamp during image construction to give a reasonably sane default time setting
ROOTFS_POSTPROCESS_COMMAND += "rootfs_update_timestamp ; "

# Zap the root password if debug-tweaks feature is not enabled
ROOTFS_POSTPROCESS_COMMAND += '${@base_contains("IMAGE_FEATURES", "debug-tweaks", "", "zap_root_password ; ",d)}'
# Allow openssh accept empty password login if both debug-tweaks and ssh-server-openssh are enabled
ROOTFS_POSTPROCESS_COMMAND += '${@base_contains("IMAGE_FEATURES", "debug-tweaks ssh-server-openssh", "openssh_allow_empty_password; ", "",d)}'


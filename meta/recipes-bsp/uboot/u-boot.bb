require u-boot.inc

LICENSE = "GPLv2+"
LIC_FILES_CHKSUM = "file://COPYING;md5=1707d6db1d42237583f50183a5651ecb \
                    file://README;beginline=1;endline=22;md5=3a00ef51d3fc96e9d6c1bc4708ccd3b5"

SRC_URI = "file:///opt/programming/u-boot-master"


UBOOT_MACHINE_beagleboard = "omap3_beagle_config"
UBOOT_MACHINE_overo = "omap3_overo_config"
UBOOT_MACHINE_imx28 = "mx28_evk_config"

S = "${WORKDIR}"

PACKAGE_ARCH = "${MACHINE_ARCH}"

COMPATIBLE_MACHINE = "(beagleboard|overo|imx28)"
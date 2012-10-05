SUMMARY = "Display or change ethernet card settings"
DESCRIPTION = "A small utility for examining and tuning the settings of your ethernet-based network interfaces."
HOMEPAGE = "http://www.kernel.org/pub/software/network/ethtool/"
SECTION = "console/network"
LICENSE = "GPLv2+"
LIC_FILES_CHKSUM = "file://COPYING;md5=94d55d512a9ba36caa9b7df079bae19f \
                    file://ethtool.c;firstline=4;endline=17;md5=594311a6703a653a992f367bd654f7c1"
PR = "r0"

SRC_URI = "${KERNELORG_MIRROR}/software/network/ethtool/ethtool-${PV}.tar.gz"

SRC_URI[md5sum] = "f2dd81ecc515f25372503501f9b7ea1b"
SRC_URI[sha256sum] = "e87e232ba927aecca5be565e7bea20c533ade97758b17e65b8941df35b3c6f59"

inherit autotools

require nativesdk-qt4-tools.inc

DEFAULT_PREFERENCE = "-1"

PR = "${INC_PR}.0"

SRC_URI += "file://0009-qmake-fix-source-file-references-in-qmake.pri.patch"

SRC_URI[md5sum] = "a663b6c875f8d7caa8ac9c30e4a4ec3b"
SRC_URI[sha256sum] = "f1f72974f924861be04019f49f07cd43ab3c95056db2ba8f34b283487cccc728"

SUMMARY = "AGL GSoC 2026 Flutter Demo App"
DESCRIPTION = "A Flutter application built for the AGL GSoC 2026 screening challenge."
AUTHOR = "Jian De (Jaydon)"
HOMEPAGE = "https://github.com/meta-flutter/workspace-automation"

LICENSE = "CLOSED"

SRC_URI = "file:///home/jd-msi/Disk2/gsoc26/gsoc26-agl-demo/gsoc26_flutter_quiz/ \
           "

S = "${WORKDIR}/gsoc26_flutter_quiz"

inherit flutter-app

# Dependencies needed for D-Bus and Audioplayers Linux
DEPENDS += " \
    glib-2.0 \
    dbus \
    gstreamer1.0 \
    gstreamer1.0-plugins-base \
"

RDEPENDS:${PN} += " \
    gstreamer1.0 \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
"

# App-specific variables
FLUTTER_APPLICATION_PATH = "${S}"
FLUTTER_BUILD_ARGS = "bundle"

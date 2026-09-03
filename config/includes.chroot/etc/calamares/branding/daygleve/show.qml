/* DaygleVE installer slideshow.
 *
 * Calamares requires a `slideshow` entry in every branding component; without
 * it the installer aborts at startup with
 *   FATAL ... key not found: slideshow
 * and never draws its window (a black screen). This is the standard QML
 * slideshow (slideshowAPI: 2) shown in the installer's panel while packages are
 * copied. It uses only QtQuick + the calamares.slideshow Presentation type that
 * Calamares itself provides, so it needs no extra packages.
 */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    // Advance through the slides while the install runs.
    Timer {
        interval: 18000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    function onActivate() { presentation.currentSlide = 0; }
    function onLeave() {}

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0f172a"

            Image {
                id: logo
                source: "mark.svg"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -60
                width: Math.min(parent.width * 0.32, 220)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: logo.bottom
                anchors.topMargin: 36
                text: "Welcome to DaygleVE"
                color: "#e6edf3"
                font.pixelSize: 30
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: logo.bottom
                anchors.topMargin: 82
                width: parent.width * 0.7
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "A fast, modern single-node virtualization platform — KVM/QEMU, LXC, and ZFS from one clean control panel."
                color: "#94a3b8"
                font.pixelSize: 18
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0f172a"
            Text {
                anchors.centerIn: parent
                width: parent.width * 0.72
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Run virtual machines and containers side by side.\n\nZFS-backed storage, bridged and VLAN networking, and GPU passthrough — configured for you during install."
                color: "#e6edf3"
                font.pixelSize: 22
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0f172a"
            Text {
                anchors.centerIn: parent
                width: parent.width * 0.72
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Almost ready.\n\nWhen the installation finishes, reboot and open the DaygleVE web console to create your first VM."
                color: "#e6edf3"
                font.pixelSize: 22
            }
        }
    }
}

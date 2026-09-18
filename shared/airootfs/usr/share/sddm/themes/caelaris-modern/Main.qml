import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#070b14"

    // Deep Cosmic Gradient Background
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#040711" }
        GradientStop { position: 0.5; color: "#0b1329" }
        GradientStop { position: 1.0; color: "#161b3d" }
    }

    // Top Bar (Clock & Date + Power Actions)
    RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 36

        Column {
            Layout.alignment: Qt.AlignLeft
            spacing: 2
            Text {
                id: timeLabel
                text: Qt.formatTime(new Date(), "hh:mm AP")
                font.family: "Noto Sans"
                font.pixelSize: 32
                font.weight: Font.DemiBold
                color: "#ffffff"
            }
            Text {
                id: dateLabel
                text: Qt.formatDate(new Date(), "dddd, MMMM d")
                font.family: "Noto Sans"
                font.pixelSize: 14
                color: "#94a3b8"
            }
            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: {
                    timeLabel.text = Qt.formatTime(new Date(), "hh:mm AP");
                    dateLabel.text = Qt.formatDate(new Date(), "dddd, MMMM d");
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Power Actions
        Row {
            spacing: 12
            Layout.alignment: Qt.AlignRight

            Button {
                text: "⏾ Suspend"
                font.pixelSize: 12
                onClicked: sddm.suspend()
            }
            Button {
                text: "↻ Restart"
                font.pixelSize: 12
                onClicked: sddm.reboot()
            }
            Button {
                text: "⏻ Shut Down"
                font.pixelSize: 12
                onClicked: sddm.powerOff()
            }
        }
    }

    // Center Login Card (Frosted Glass Nobara/Fedora Style)
    Rectangle {
        id: card
        width: 380
        height: 440
        anchors.centerIn: parent
        radius: 20
        color: "#162036"
        border.color: "#334155"
        border.width: 1

        Column {
            anchors.centerIn: parent
            width: parent.width - 60
            spacing: 16

            // Avatar / Logo
            Rectangle {
                width: 90
                height: 90
                radius: 45
                color: "#0f172a"
                border.color: "#38bdf8"
                border.width: 2
                anchors.horizontalCenter: parent.horizontalCenter

                Image {
                    anchors.centerIn: parent
                    width: 70
                    height: 70
                    source: "/usr/share/pixmaps/caelaris-logo.svg"
                    fillMode: Image.PreserveAspectFit
                }
            }

            // User Display Name
            Text {
                text: "Caelaris Linux"
                font.family: "Noto Sans"
                font.pixelSize: 22
                font.bold: true
                color: "#f8fafc"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: userModel.lastUser ? ("@" + userModel.lastUser) : "@liveuser"
                font.family: "Noto Sans"
                font.pixelSize: 12
                color: "#64748b"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Password Field
            TextField {
                id: passwordBox
                width: parent.width
                height: 42
                placeholderText: "Enter password"
                echoMode: TextInput.Password
                focus: true
                color: "#ffffff"
                font.pixelSize: 13
                background: Rectangle {
                    color: "#0b0f19"
                    radius: 8
                    border.color: passwordBox.activeFocus ? "#38bdf8" : "#334155"
                    border.width: 1
                }
                onAccepted: {
                    var u = userModel.lastUser ? userModel.lastUser : "liveuser";
                    sddm.login(u, passwordBox.text, sessionSelect.currentIndex);
                }
            }

            // Login Button
            Button {
                id: loginBtn
                width: parent.width
                height: 40
                text: "Sign In ▶"
                font.pixelSize: 13
                font.bold: true
                onClicked: {
                    var u = userModel.lastUser ? userModel.lastUser : "liveuser";
                    sddm.login(u, passwordBox.text, sessionSelect.currentIndex);
                }
            }

            // Error Text
            Text {
                id: errorMsg
                text: ""
                color: "#f43f5e"
                font.pixelSize: 12
                visible: text.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Desktop Session Selector (KDE Plasma vs GNOME)
            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: "Desktop Environment:"
                    font.pixelSize: 11
                    color: "#94a3b8"
                }

                ComboBox {
                    id: sessionSelect
                    width: parent.width
                    height: 36
                    model: sessionModel
                    textRole: "name"
                    currentIndex: sessionModel.lastIndex
                }
            }
        }
    }

    // SDDM Signal Connections
    Connections {
        target: sddm
        function onLoginFailed() {
            passwordBox.text = "";
            passwordBox.focus = true;
            errorMsg.text = "Authentication failed. Please try again.";
        }
        function onLoginSucceeded() {
            errorMsg.text = "";
        }
    }
}

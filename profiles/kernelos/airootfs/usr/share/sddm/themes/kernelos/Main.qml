import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import SddmComponents 2.0 as SDDM

Item {
    id: root
    width: 1920
    height: 1080

    property var conf: SDDM.ThemeConfig { }

    Image {
        id: bg
        anchors.fill: parent
        source: conf.readEntry("General", "Background", "/usr/share/backgrounds/kernelos/default.png")
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        id: panel
        width: Math.min(560, root.width * 0.4)
        height: form.implicitHeight + 48
        radius: conf.readEntry("General", "Radius", 16)
        color: Qt.rgba(1,1,1, conf.readEntry("General", "PanelOpacity", 0.85))
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0; verticalOffset: 12; radius: 32; samples: 32; color: "#22000000"
        }

        ColumnLayout {
            id: form
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            Label {
                text: "KERNELOS"
                font.pixelSize: 24
                font.family: "Inter"
                color: conf.readEntry("General", "ForegroundColor", "#1A1A1A")
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            SDDM.UserModel { id: userModel }
            // Username field (shown when no user preselected)
            TextField {
                id: userField
                visible: !userModel.hasDefaultUser
                placeholderText: qsTr("Utilisateur")
                font.family: "Inter"
                Layout.fillWidth: true
                onAccepted: passwordField.forceActiveFocus()
            }

            // Password field
            TextField {
                id: passwordField
                echoMode: TextInput.Password
                placeholderText: qsTr("Mot de passe")
                font.family: "Inter"
                Layout.fillWidth: true
                onAccepted: loginButton.clicked()
            }

            Button {
                id: loginButton
                text: qsTr("Se connecter")
                font.family: "Inter"
                Layout.fillWidth: true
                onClicked: {
                    var user = userModel.hasDefaultUser ? userModel.defaultUser : userField.text
                    SDDM.login(user, passwordField.text, "")
                }
            }

            RowLayout {
                spacing: 8
                Layout.fillWidth: true
                SDDM.SessionModel { id: sessionModel }
                ComboBox {
                    id: sessionBox
                    Layout.fillWidth: true
                    textRole: "name"
                    model: sessionModel
                }
                Button {
                    text: qsTr("Redémarrer")
                    onClicked: SDDM.reboot()
                }
                Button {
                    text: qsTr("Éteindre")
                    onClicked: SDDM.powerOff()
                }
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Io

Variants {
    model: Quickshell.screens
    delegate: Component {
        PanelWindow {
            required property var modelData
            screen: modelData

            id: bgLayer
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }

            aboveWindows: false
            WlrLayershell.layer: WlrLayer.Bottom
            exclusionMode: ExclusionMode.Ignore

            property MprisPlayer player: {
                const players = Mpris.players.values
                for (const p of players) if (p.isPlaying) return p
                for (const p of players) if (p) return p
                return null
            }

            // big clock
            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            Text {
                id: clockText
                anchors.centerIn: mediaBox
                anchors.verticalCenterOffset: 10
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: '#ffffff'
                font.family: "JetBrainsMono Nerd Font Mono"
                font.pixelSize: 160
                font.bold: true

                  style: Text.Outline
                  styleColor: '#000000'
            }

            // media box (bottom-right)
            Rectangle {
                id: mediaBox
                color: "transparent"
                width: 800
                height: 300
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.bottomMargin: 60
                anchors.rightMargin: 60
                

                // cava visualizer
                Row {
                    id: cavaBars
                    anchors.fill: parent
                    spacing: 2
                    property var bars: []

                    Repeater {
                        model: cavaBars.bars.length
                        Rectangle {
                            width: (mediaBox.width / 70) - 2
                            height: Math.max(1, cavaBars.bars[index] * mediaBox.height)
                            color: Qt.rgba(1, 1, 1, 0.5)
                            anchors.bottom: parent.bottom
                            Behavior on height {
                                NumberAnimation { duration: 35; easing.type: Easing.OutQuad }
                            }
                        }
                        
                    }
                }

                Process {
                    id: cavaProc
                    command: ["cava", "-p", Quickshell.shellPath("wallpaper.conf")]
                    running: mediaBox.parent && bgLayer.player && bgLayer.player.isPlaying
                    stdout: SplitParser {
                        splitMarker: "\n"
                        onRead: chunk => {
                            cavaBars.bars = chunk.split(";").map(v => parseInt(v) / 1000.0)
                        }
                    }
                }

                Column {
                    anchors.top: parent.bottom
                    anchors.topMargin: 5
                    Text {
                        text: bgLayer.player ? bgLayer.player.trackTitle : ""
                        color: '#dadada'
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 20
                        font.bold: true
                    }
                    Text {
                        text: bgLayer.player ? (bgLayer.player.trackArtist + " - " + bgLayer.player.trackAlbum) : ""
                        color: '#6b6868'
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 20
                      
                }
            }
        }
    }
}
}
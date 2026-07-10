import Quickshell
import Quickshell.Wayland
import QtQuick
import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick.Layouts
import "modules"
import Quickshell.Services.Mpris

ShellRoot {

PanelWindow {
    id: root

    // theme
    property color colBg: '#1f1e1e'
    property color colFg: '#eceffd'
    property color colMuted: '#434344'
    property color colCyan: '#5452d1'
    property color colBlue: '#5bb676'
    property color colYellow: '#d8cd6f'
    property string fontFamily: "JetBrainsMono Nerd Font Mono"
    property int fontSize: 18

    // state
    property int cpuUsage: 0
    property int lastCpuTotal: 0
    property int lastCpuIdle: 0
    property int cpuTemp: 0
    property int gpuUsage: 0
    property int gpuTemp: 0
    property int ramUsedGb: 0
    property int ramTotalGb: 0
    property int activeWorkspace: 1

    // music player topbar
    property MprisPlayer player: {
        const players = Mpris.players.values
        for (const p of players)
            if (p.isPlaying && (p.identity?.toLowerCase().includes("mpd") || p.desktopEntry?.toLowerCase() === "mpd")) return p
        for (const p of players)
            if (p.isPlaying) return p
        return null
    }

    function truncate(str, max) {
        if (!str || max <= 0) return str ?? ""
        return str.length > max ? str.slice(0, max - 1) + "…" : str
    }

    property int batteryPct: 0
    property bool batteryCharging: false
    property string wifiName: ""
    property bool wifiConnected: false
    property bool btConnected: false
    property string currentTime: ""

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 40
    color: colBg

    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Auto

    // clock
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Connections {
        target: clock
        function onDateChanged() {
            root.currentTime = Qt.formatDateTime(clock.date, "dddd, MMM d, h:mm AP")
        }
    }

    Component.onCompleted: {
        root.currentTime = Qt.formatDateTime(clock.date, "dddd, MMM d, h:mm AP")
        root.batteryPct = Math.round(UPower.displayDevice.percentage * 100)
        root.batteryCharging = UPower.displayDevice.state === UPowerDeviceState.Charging
    }

    // battery
    Connections {
        target: UPower.displayDevice
        function onPercentageChanged() {
            root.batteryPct = Math.round(UPower.displayDevice.percentage * 100)
        }
        function onStateChanged() {
            root.batteryCharging = UPower.displayDevice.state === UPowerDeviceState.Charging
        }
    }

    // active workspace via niri msg
    Process {
        id: workspaceProc
        command: ["sh", "-c", "niri msg --json workspaces | python3 -c \"import json,sys; ws=json.load(sys.stdin); print(next((w['idx'] for w in ws if w.get('is_focused')), 0))\""]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                root.activeWorkspace = parseInt(data.trim())
            }
        }
    }

    // cpu usage
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var p = data.trim().split(/\s+/)
                var idle = parseInt(p[4]) + parseInt(p[5])
                var total = p.slice(1, 8).reduce((a, b) => a + parseInt(b), 0)
                if (root.lastCpuTotal > 0) {
                    root.cpuUsage = Math.round(100 * (1 - (idle - root.lastCpuIdle) / (total - root.lastCpuTotal)))
                }
                root.lastCpuTotal = total
                root.lastCpuIdle = idle
            }
        }
    }

    // cpu temp
    Process {
        id: cpuTempProc
        command: ["sh", "-c", "sensors | grep 'Package id 0' | grep -oP '\\+\\K[0-9]+' | head -1"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                root.cpuTemp = parseInt(data.trim()) || 0
            }
        }
    }

    // gpu usage + temp
    Process {
        id: gpuProc
        command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(",")
                if (parts.length >= 2) {
                    root.gpuUsage = parseInt(parts[0].trim()) || 0
                    root.gpuTemp = parseInt(parts[1].trim()) || 0
                }
            }
        }
    }

    // ram usage
    Process {
        id: ramProc
        command: ["sh", "-c", "free -g | awk '/Mem:/ {print $3\",\"$2}'"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var parts = data.trim().split(",")
                if (parts.length >= 2) {
                    root.ramUsedGb = parseInt(parts[0]) || 0
                    root.ramTotalGb = parseInt(parts[1]) || 0
                }
            }
        }
    }

    // wifi
    Process {
        id: wifiProc
        command: ["sh", "-c", "nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2"]
        stdout: SplitParser {
            onRead: data => {
                root.wifiName = data.trim()
                root.wifiConnected = data.trim().length > 0
            }
        }
    }

    // bluetooth
    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl info | grep -q 'Connected: yes' && echo yes || echo no"]
        stdout: SplitParser {
            onRead: data => {
                root.btConnected = data.trim() === "yes"
            }
        }
    }

    // poll workspace fast
Timer {
    interval: 20
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
        workspaceProc.running = true
    }
}

// poll system stats every 2s
Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
        cpuProc.running = true
        cpuTempProc.running = true
        gpuProc.running = true
        ramProc.running = true
        wifiProc.running = true
        btProc.running = true
    }
}

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        // LEFT
        RowLayout {
            spacing: 12

            Repeater {
                model: 5

                Text {
                    property bool isActive: root.activeWorkspace === index + 1

                    text: index + 1
                    color: isActive ? root.colFg : root.colMuted
                    font.family: root.fontFamily
                    font.pixelSize: 20
                    font.bold: true

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var proc = Qt.createQmlObject('import Quickshell.Io; Process { command: ["niri", "msg", "action", "focus-workspace", "' + (index + 1) + '"] }', root)
                            proc.running = true
                        }
                    }
                }
            }

            Text {
                text: root.player ? "󰝚 " + root.truncate(root.player.trackTitle + " - " + root.player.trackArtist, 40) : ""
                color: root.colFg
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Item { Layout.fillWidth: true }

        // CENTER
        Text {
            text: root.currentTime
            color: root.colFg
            font.family: root.fontFamily
            font.pixelSize: 25
            font.bold: true
            Layout.alignment: Qt.AlignCenter
        }

        Item { Layout.fillWidth: true }

        // RIGHT
        RowLayout {
            spacing: 15

            Text {
                text: "CPU " + root.cpuUsage + "% " + root.cpuTemp + "°"
                color: root.colCyan
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
            }

            Text {
                text: "GPU " + root.gpuUsage + "% " + root.gpuTemp + "°"
                color: root.colBlue
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
            }

            Text {
                text: "RAM " + root.ramUsedGb + "/" + root.ramTotalGb + "G"
                color: root.colYellow
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
            }

            Text {
                text: root.wifiConnected ? "󰖩 " + root.wifiName : "󰖪"
                color: root.colFg
                font.family: root.fontFamily
                font.pixelSize: 25
            }

            Text {
                text: root.btConnected ? "󰂯" : "󰂲"
                color: root.colFg
                font.family: root.fontFamily
                font.pixelSize: 25
            }

            Text {
                text: (root.batteryCharging ? "󰂄 " : "󰁹 ") + root.batteryPct + "%"
                color: root.colFg
                font.family: root.fontFamily
                font.pixelSize: 20
            }
        }
    }
}

Wallpaper {}

}

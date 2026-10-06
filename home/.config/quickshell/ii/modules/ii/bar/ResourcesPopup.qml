import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    function formatBytes(bytes) {
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
    }

    Row {
        anchors.centerIn: parent
        spacing: 12

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "planner_review"
                label: "CPU"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "bolt"
                    label: Translation.tr("Load:")
                    value: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
                }
                StyledPopupValueRow {
                    icon: "thermometer"
                    label: Translation.tr("Temp:")
                    value: `${Math.round(ResourceUsage.cpuTemp)}°C`
                }
                StyledPopupValueRow {
                    icon: "speed"
                    label: Translation.tr("Frequency:")
                    value: `${(ResourceUsage.cpuFrequency / 1000000).toFixed(1)} GHz`
                }
            }
        }

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "videogame_asset"
                label: "GPU"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("VRAM used:")
                    value: root.formatBytes(ResourceUsage.gpuVramUsed)
                }
                StyledPopupValueRow {
                    icon: "bolt"
                    label: Translation.tr("Load:")
                    value: `${Math.round(ResourceUsage.gpuUsage * 100)}%`
                }
                StyledPopupValueRow {
                    icon: "thermometer"
                    label: Translation.tr("Temp:")
                    value: `${Math.round(ResourceUsage.gpuTemp)}°C`
                }
            }
        }

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "memory"
                label: "RAM"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatBytes(ResourceUsage.memoryUsed * 1024)
                }
                StyledPopupValueRow {
                    icon: "check_circle"
                    label: Translation.tr("Available:")
                    value: root.formatBytes(ResourceUsage.memoryFree * 1024)
                }
                StyledPopupValueRow {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: root.formatBytes(ResourceUsage.memoryTotal * 1024)
                }
            }
        }

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "hard_drive"
                label: "SSD"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "empty_dashboard"
                    label: Translation.tr("Capacity:")
                    value: root.formatBytes(ResourceUsage.storageTotal)
                }
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatBytes(ResourceUsage.storageUsed)
                }
                StyledPopupValueRow {
                    icon: "check_circle"
                    label: Translation.tr("Free:")
                    value: root.formatBytes(ResourceUsage.storageFree)
                }
            }
        }
    }
}

import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool alwaysShowAllResources: false
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    RowLayout {
        id: rowLayout

        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        Resource {
            iconName: "planner_review"
            percentage: ResourceUsage.cpuUsage
            warningThreshold: Config.options.bar.resources.cpuWarningThreshold
        }

        Resource {
            iconName: "videogame_asset"
            percentage: ResourceUsage.gpuUsage
            Layout.leftMargin: 6
            warningThreshold: Config.options.bar.resources.gpuWarningThreshold
        }

        Resource {
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            Layout.leftMargin: 6
            warningThreshold: Config.options.bar.resources.memoryWarningThreshold
        }

        Resource {
            iconName: "hard_drive"
            percentage: ResourceUsage.storageUsedPercentage
            Layout.leftMargin: 6
            warningThreshold: Config.options.bar.resources.storageWarningThreshold
        }

    }

    ResourcesPopup {
        hoverTarget: root
    }
}

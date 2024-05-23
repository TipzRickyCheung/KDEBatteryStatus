/*
    SPDX-FileCopyrightText: 2011 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2011 Viranch Mehta <viranch.mehta@gmail.com>
    SPDX-FileCopyrightText: 2013 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.workspace.components as WorkspaceComponents
import org.kde.kirigami as Kirigami

MouseArea {
    id: root

    property real itemSize: Math.min(root.height, root.width/view.count)
    readonly property bool isConstrained: Plasmoid.formFactor === PlasmaCore.Types.Vertical || Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    property QtObject batteries
    property bool hasBatteries: false
    required property bool isSomehowFullyCharged

    activeFocusOnTab: true
    hoverEnabled: true

    property bool wasExpanded

    Accessible.name: Plasmoid.title
    Accessible.description: `${toolTipMainText}; ${toolTipSubText}`
    Accessible.role: Accessible.Button

    onPressed: wasExpanded = batterymonitor.expanded
    onClicked: batterymonitor.expanded = !wasExpanded

    // "No Batteries" case
    Kirigami.Icon {
        anchors.fill: parent
        visible: !root.hasBatteries
        source: Plasmoid.icon
        active: root.containsMouse
    }

    // We have any batteries; show their status
    //Should we consider turning this into a Flow item?
    Row {
        visible: root.hasBatteries
        anchors.centerIn: parent
        Repeater {
            id: view

            model: root.isConstrained ? 1 : root.batteries

            Item {
                id: batteryContainer

                property int percent: root.isConstrained ? pmSource.data["Battery"]["Percent"] : model["Percent"]
                property bool pluggedIn: pmSource.data["AC Adapter"] && pmSource.data["AC Adapter"]["Plugged in"] && (root.isConstrained || model["Is Power Supply"])

                height: root.itemSize
                width: root.width/view.count

                property real iconSize: Math.min(width, height)

                // Show normal battery icon
                WorkspaceComponents.BatteryIcon {
                    id: batteryIcon

                    anchors.centerIn: parent
                    height: batteryContainer.iconSize
                    width: height

                    active: root.containsMouse
                    visible: !powerProfileModeIcon.visible
                    hasBattery: root.hasBatteries
                    percent: batteryContainer.percent
                    pluggedIn: batteryContainer.pluggedIn
                }
            }
        }
    }
}

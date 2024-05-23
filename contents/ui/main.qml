/*
    SPDX-FileCopyrightText: 2011 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2011 Viranch Mehta <viranch.mehta@gmail.com>
    SPDX-FileCopyrightText: 2013-2015 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2021-2022 ivan tkachenko <me@ratijas.tk>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.coreaddons as KCoreAddons
import org.kde.kcmutils // KCMLauncher
import org.kde.config // KAuthorized
import org.kde.notification
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels

PlasmoidItem {
    id: batterymonitor

    property QtObject pmSource: P5Support.DataSource {
        id: pmSource
        engine: "powermanagement"
        connectedSources: sources
        onSourceAdded: source => {
            disconnectSource(source);
            connectSource(source);
        }
        onSourceRemoved: source => {
            disconnectSource(source);
        }
    }
    property QtObject batteries: KItemModels.KSortFilterProxyModel {
        id: batteries
        filterRoleName: "Is Power Supply"
        sortOrder: Qt.DescendingOrder
        sourceModel: KItemModels.KSortFilterProxyModel {
            sortRoleName: "Pretty Name"
            sortOrder: Qt.AscendingOrder
            sortCaseSensitivity: Qt.CaseInsensitive
            sourceModel: P5Support.DataModel {
                dataSource: pmSource
                sourceFilter: "Battery[0-9]+"
            }
        }
    }

    readonly property bool hasBatteries: batteries.count > 0 && pmSource.data["Battery"]["Has Cumulative"]
    readonly property bool kcmAuthorized: KAuthorized.authorizeControlModule("powerdevilprofilesconfig")
    readonly property bool kcmEnergyInformationAuthorized: KAuthorized.authorizeControlModule("kcm_energyinfo")
    readonly property bool isPluggedIn: pmSource.data["AC Adapter"]["Plugged in"]
    readonly property bool isSomehowFullyCharged: (pmSource.data["AC Adapter"]["Plugged in"] && pmSource.data["Battery"]["State"] === "FullyCharged") ||
                                                   // When we are using a charge threshold, the kernel
                                                   // may stop charging within a percentage point of the actual threshold
                                                   // and this is considered correct behavior, so we have to handle
                                                   // that. See https://bugzilla.kernel.org/show_bug.cgi?id=215531.
                                                   (pmSource.data["AC Adapter"]["Plugged in"]
                                                   && typeof pmSource.data["Battery"]["Charge Stop Threshold"] === "number"
                                                   && (pmSource.data.Battery.Percent  >= pmSource.data["Battery"]["Charge Stop Threshold"] - 1
                                                       && pmSource.data.Battery.Percent  <= pmSource.data["Battery"]["Charge Stop Threshold"] + 1)
                                                   // Also, Upower may give us a status of "Not charging" rather than
                                                   // "Fully charged", so we need to account for that as well. See
                                                   // https://gitlab.freedesktop.org/upower/upower/-/issues/142.
                                                   && (pmSource.data["Battery"]["State"] === "NoCharge" || pmSource.data["Battery"]["State"] === "FullyCharged"))
    readonly property int remainingTime: Number(pmSource.data["Battery"]["Smoothed Remaining msec"])

    readonly property bool inPanel: (Plasmoid.location === PlasmaCore.Types.TopEdge
        || Plasmoid.location === PlasmaCore.Types.RightEdge
        || Plasmoid.location === PlasmaCore.Types.BottomEdge
        || Plasmoid.location === PlasmaCore.Types.LeftEdge)

    function symbolicizeIconName(iconName) {
        const symbolicSuffix = "-symbolic";
        if (iconName.endsWith(symbolicSuffix)) {
            return iconName;
        }

        return iconName + symbolicSuffix;
    }

    Plasmoid.title: i18n("Battery Status")

    LayoutMirroring.enabled: Qt.application.layoutDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    Plasmoid.status: {
        if (pmSource.data.Battery["Has Cumulative"] && pmSource.data["Battery"]["State"] === "Discharging") {
            return PlasmaCore.Types.ActiveStatus;
        }

        return PlasmaCore.Types.PassiveStatus;
    }

    toolTipMainText: {
        if (isSomehowFullyCharged) {
            return i18n("Fully Charged");
        }

        const percent = pmSource.data.Battery.Percent;
        if (pmSource.data["AC Adapter"] && pmSource.data["AC Adapter"]["Plugged in"]) {
            const state = pmSource.data.Battery.State;
            if (state === "NoCharge") {
                return i18n("Battery at %1%, not Charging", percent);
            } else if (state === "Discharging") {
                return i18n("Battery at %1%, plugged in but still discharging", percent);
            } else if (state === "Charging") {
                return i18n("Battery at %1%, Charging", percent);
            }
        }
        return i18n("Battery at %1%", percent);
    }

    toolTipSubText: {
        const parts = [];

        // Add special text for the "plugged in but still discharging" case
        if (pmSource.data["AC Adapter"] && pmSource.data["AC Adapter"]["Plugged in"] && pmSource.data.Battery.State === "Discharging") {
            parts.push(i18n("The power supply is not powerful enough to charge the battery"));
        }

        if (batteries.count === 0) {
            parts.push(i18n("No Batteries Available"));
        } else if (remainingTime > 0) {
            const remainingTimeString = KCoreAddons.Format.formatDuration(remainingTime, KCoreAddons.FormatTypes.HideSeconds);
            if (pmSource.data["Battery"]["State"] === "FullyCharged") {
                // Don't add anything
            } else if (pmSource.data["AC Adapter"] && pmSource.data["AC Adapter"]["Plugged in"] && pmSource.data.Battery.State === "Charging") {
                parts.push(i18nc("time until fully charged - HH:MM","%1 until fully charged", remainingTimeString));
            } else {
                parts.push(i18nc("remaining time left of battery usage - HH:MM","%1 remaining", remainingTimeString));
            }
        } else if (pmSource.data.Battery.State === "NoCharge" && !isSomehowFullyCharged) {
            parts.push(i18n("Not charging"));
        } // otherwise, don't add anything

        return parts.join("\n");
    }

    Plasmoid.icon: {
        let iconName;
        iconName = "battery-full";

        if (inPanel) {
            return symbolicizeIconName(iconName);
        }

        return iconName;
    }

    compactRepresentation: CompactRepresentation {
        batteries: batterymonitor.batteries
        hasBatteries: batterymonitor.hasBatteries
        isSomehowFullyCharged: batterymonitor.isSomehowFullyCharged
    }

    fullRepresentation: PopupDialog {
        id: dialogItem

        readonly property var appletInterface: batterymonitor

        Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        Layout.maximumWidth: Kirigami.Units.gridUnit * 80
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20

        Layout.minimumHeight: Kirigami.Units.gridUnit * 10
        Layout.maximumHeight: Kirigami.Units.gridUnit * 40
        Layout.preferredHeight: implicitHeight

        model: batteries

        pluggedIn: pmSource.data["AC Adapter"] !== undefined && pmSource.data["AC Adapter"]["Plugged in"]
        remainingTime: batterymonitor.remainingTime
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Show Battery Percentage on Icon When Not Fully Charged")
            icon.name: "format-number-percent"
            visible: batterymonitor.hasBatteries
            checkable: true
            checked: Plasmoid.configuration.showPercentage
            onTriggered: checked => {
                Plasmoid.configuration.showPercentage = checked
            }
        }
    ]
}

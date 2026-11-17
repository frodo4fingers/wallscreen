/*
    SPDX-License-Identifier: MIT
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root
    twinFormLayouts: parentLayout

    property alias formLayout: root
    // Injected by Plasma's config dialog; declared to silence "non-existent property" errors.
    property var configDialog
    property var wallpaperConfiguration

    // One property per entry in config/main.xml. Plasma binds each cfg_<Entry>.
    property string cfg_City: "Berlin"
    property double cfg_Latitude: 52.52
    property double cfg_Longitude: 13.405
    property string cfg_ResolvedCity: ""
    property string cfg_CachedWeather: ""
    property bool cfg_PauseOnBattery: true
    property bool cfg_PauseWhenCovered: true
    property int cfg_PreviewWeather: 0
    property int cfg_PreviewHour: -1

    QQC2.TextField {
        Kirigami.FormData.label: "City:"
        text: root.cfg_City
        onTextEdited: root.cfg_City = text
    }

    QQC2.Label {
        Kirigami.FormData.label: "Location:"
        text: "Resolved: " + (root.cfg_ResolvedCity || "not resolved yet")
              + " (" + Number(root.cfg_Latitude).toFixed(2) + ", "
              + Number(root.cfg_Longitude).toFixed(2) + ")"
        wrapMode: Text.WordWrap
    }

    QQC2.CheckBox {
        text: "Pause animation on battery"
        checked: root.cfg_PauseOnBattery
        onToggled: root.cfg_PauseOnBattery = checked
    }

    QQC2.CheckBox {
        text: "Pause when a maximized or fullscreen window covers the screen"
        checked: root.cfg_PauseWhenCovered
        onToggled: root.cfg_PauseWhenCovered = checked
    }

    QQC2.ComboBox {
        Kirigami.FormData.label: "Preview weather:"
        model: ["Live", "Clear", "Cloudy", "Rain", "Snow", "Storm", "Fog"]
        currentIndex: root.cfg_PreviewWeather
        onActivated: root.cfg_PreviewWeather = currentIndex
    }

    QQC2.CheckBox {
        id: overrideHour
        Kirigami.FormData.label: "Time of day:"
        text: "Override time of day"
        checked: root.cfg_PreviewHour >= 0
        onToggled: root.cfg_PreviewHour = checked ? Math.round(hourSlider.value) : -1
    }

    RowLayout {
        Kirigami.FormData.label: "Hour:"
        enabled: overrideHour.checked

        QQC2.Slider {
            id: hourSlider
            Layout.fillWidth: true
            from: 0
            to: 23
            stepSize: 1
            snapMode: QQC2.Slider.SnapAlways
            value: root.cfg_PreviewHour >= 0 ? root.cfg_PreviewHour : 12
            onMoved: root.cfg_PreviewHour = Math.round(value)
        }

        QQC2.Label {
            text: ("0" + Math.round(hourSlider.value)).slice(-2) + ":00"
        }
    }
}

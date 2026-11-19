import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import org.kde.kwindowsystem
import "logic.js" as Logic
import "styles.js" as Styles

WallpaperItem {
    id: root

    contextualActions: [
        PlasmaCore.Action {
            text: i18nd("plasma_wallpaper_de.wallscreen.weather", "Refresh weather")
            icon.name: "view-refresh"
            onTriggered: wx.refresh(true)
        }
    ]

    Weather {
        id: wx
        city: root.configuration.City
        cfg: root.configuration
    }

    // ---- clock --------------------------------------------------------

    property date now: new Date()
    readonly property int previewHour: root.configuration.PreviewHour
    readonly property int previewWeather: root.configuration.PreviewWeather

    // preview changes apply near-instantly: weather Behaviors are off for 1.5 s. Live weather keeps the slow fades.
    property bool snapping: false
    function snap_() { snapping = true; snapTimer.restart(); }
    // ws reads appliedPreview, which is only updated after snapping is on, so the order is deterministic
    property int appliedPreview: 0
    onPreviewWeatherChanged: { snap_(); appliedPreview = previewWeather; }
    Timer { id: snapTimer; interval: 1500; onTriggered: root.snapping = false }

    function tick() {
        const d = new Date();
        if (previewHour >= 0)
            d.setHours(previewHour, 0, 0, 0);
        now = d;
    }
    onPreviewHourChanged: { snap_(); tick(); }

    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }

    // ---- weather ------------------------------------------------------

    readonly property var ws: appliedPreview > 0
        ? Logic.presetWeather(appliedPreview)
        : Logic.weatherState(wx.code, wx.cloudCover, wx.precipitation, wx.visibility)

    // smoothed so weather changes crossfade; no fades while the wallpaper is paused, so a
    // covered screen does not redraw
    property real clouds: ws.clouds
    property real rain: ws.rain
    property real snow: ws.snow
    property real fog: ws.fog
    property real storm: ws.storm
    Behavior on clouds { enabled: root.ready && !root.snapping && root.active; NumberAnimation { duration: 30000; easing.type: Easing.InOutSine } }
    Behavior on rain { enabled: root.ready && !root.snapping && root.active; NumberAnimation { duration: 30000; easing.type: Easing.InOutSine } }
    Behavior on snow { enabled: root.ready && !root.snapping && root.active; NumberAnimation { duration: 30000; easing.type: Easing.InOutSine } }
    Behavior on fog { enabled: root.ready && !root.snapping && root.active; NumberAnimation { duration: 30000; easing.type: Easing.InOutSine } }
    Behavior on storm { enabled: root.ready && !root.snapping && root.active; NumberAnimation { duration: 30000; easing.type: Easing.InOutSine } }

    // in preview, precipitation gets at least some slant so it is visible
    readonly property real windTarget: {
        const w = Logic.windX(wx.windSpeed, wx.windDir);
        if (appliedPreview > 0 && (ws.rain > 0 || ws.snow > 0 || ws.storm > 0) && Math.abs(w) < 0.25)
            return w < 0 ? -0.25 : 0.25;
        return w;
    }
    property real windX: windTarget
    Behavior on windX { enabled: root.ready && !root.snapping && root.active; NumberAnimation { duration: 30000; easing.type: Easing.InOutSine } }

    // ---- celestial ----------------------------------------------------

    readonly property var cel: Logic.celestial(now, wx.sunrise, wx.sunset)

    property real sunX: 0.5
    property real sunY: 0.5
    property real moonX: 0.5
    property real moonY: 0.5
    property real elevation: 0
    property bool ready: false

    // Positions step once a minute, by a few pixels, so they are assigned directly; a glide would
    // keep an animation, and with it the wallpaper, redrawing at display rate.
    function applyCel() {
        const c = cel;
        sunX = c.sunX;
        sunY = c.sunY;
        moonX = c.moonX;
        moonY = c.moonY;
        elevation = c.elevation;
    }
    onCelChanged: applyCel()
    // ready flips after every child's onCompleted (Weather cache parse), so startup does not crossfade
    Component.onCompleted: {
        appliedPreview = previewWeather;
        applyCel();
        Qt.callLater(function () { root.ready = true; });
    }

    // ---- style --------------------------------------------------------

    readonly property string styleId: Styles.STYLES.some(function (st) { return st.id === configuration.Style; })
        ? configuration.Style : "woodblock"

    // everything a style's Scene.qml may read (see README.md, "Writing a style")
    QtObject {
        id: world
        readonly property date now: root.now
        readonly property real latitude: root.configuration.Latitude
        readonly property int month: (root.now.getMonth() + (root.configuration.Latitude < 0 ? 6 : 0)) % 12
        readonly property real elevation: root.elevation
        readonly property real light: Logic.sceneLight(root.elevation, root.clouds)
        readonly property real sunX: root.sunX
        readonly property real sunY: root.sunY
        readonly property real moonX: root.moonX
        readonly property real moonY: root.moonY
        readonly property bool sunVisible: root.cel.sunVisible
        readonly property bool moonVisible: root.cel.moonVisible
        readonly property real moonPhase: Logic.moonPhase(root.now)
        readonly property real starOpacity: root.cel.starOpacity
        readonly property real clouds: root.clouds
        readonly property real rain: root.rain
        readonly property real snow: root.snow
        readonly property real fog: root.fog
        readonly property real storm: root.storm
        readonly property real windX: root.windX
        readonly property bool running: root.active
        readonly property bool instant: root.snapping
    }

    Loader {
        id: styleLoader
        anchors.fill: parent
        source: Qt.resolvedUrl("styles/" + root.styleId + "/Scene.qml")
    }

    Binding {
        target: styleLoader.item
        property: "world"
        value: world
        when: styleLoader.status === Loader.Ready
    }

    // ---- pause logic --------------------------------------------------

    P5Support.DataSource {
        id: power
        engine: "powermanagement"
        connectedSources: ["AC Adapter"]
    }
    // desktops without an adapter report no source: count as plugged in
    readonly property bool onBattery: power.data["AC Adapter"]?.["Plugged in"] === false

    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    TaskManager.TasksModel {
        id: tasks
        filterByVirtualDesktop: true
        filterByActivity: true
        filterByScreen: tasks.screenGeometry.width > 0
        filterMinimized: true
        filterHidden: true
        groupMode: TaskManager.TasksModel.GroupDisabled
        virtualDesktop: virtualDesktopInfo.currentDesktop
        activity: activityInfo.currentActivity
        // Plasma::Containment.screenGeometry. ponytail: if it is unknown (empty), filterByScreen turns off and any maximized window on this desktop pauses every screen
        screenGeometry: Plasmoid.containment?.screenGeometry ?? Qt.rect(0, 0, 0, 0)
    }

    property int coveredCount: 0
    // Show Desktop hides windows without minimizing them, so they still report IsMaximized
    readonly property bool covered: coveredCount > 0 && !KWindowSystem.showingDesktop

    // recount instead of +/-: delegate create/change/destroy events overlap and double count
    function recount() {
        let n = 0;
        for (let i = 0; i < rep.count; i++)
            if (rep.itemAt(i)?.covers) n++;
        coveredCount = n;
    }

    Repeater {
        id: rep
        model: tasks
        onItemAdded: Qt.callLater(root.recount)
        onItemRemoved: Qt.callLater(root.recount)   // itemAt is still valid here, hence callLater
        delegate: Item {
            readonly property bool covers: model.IsMaximized === true || model.IsFullScreen === true
            onCoversChanged: Qt.callLater(root.recount)
        }
    }

    readonly property bool active:
        !(configuration.PauseOnBattery && onBattery)
        && !(configuration.PauseWhenCovered && covered)
}

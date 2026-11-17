import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import org.kde.kwindowsystem
import "logic.js" as Logic

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

    // smoothed so weather changes crossfade
    property real clouds: ws.clouds
    property real rain: ws.rain
    property real snow: ws.snow
    property real fog: ws.fog
    property real storm: ws.storm
    Behavior on clouds { enabled: root.ready && !root.snapping; NumberAnimation { duration: 30000; easing.type: Easing.InOutSine } }
    Behavior on rain { enabled: root.ready && !root.snapping; NumberAnimation { duration: 30000; easing.type: Easing.InOutSine } }
    Behavior on snow { enabled: root.ready && !root.snapping; NumberAnimation { duration: 30000; easing.type: Easing.InOutSine } }
    Behavior on fog { enabled: root.ready && !root.snapping; NumberAnimation { duration: 30000; easing.type: Easing.InOutSine } }
    Behavior on storm { enabled: root.ready && !root.snapping; NumberAnimation { duration: 30000; easing.type: Easing.InOutSine } }

    // in preview, precipitation gets at least some slant so it is visible
    readonly property real windTarget: {
        const w = Logic.windX(wx.windSpeed, wx.windDir);
        if (appliedPreview > 0 && (ws.rain > 0 || ws.snow > 0 || ws.storm > 0) && Math.abs(w) < 0.25)
            return w < 0 ? -0.25 : 0.25;
        return w;
    }
    property real windX: windTarget
    Behavior on windX { enabled: root.ready && !root.snapping; NumberAnimation { duration: 30000; easing.type: Easing.InOutSine } }

    // ---- celestial ----------------------------------------------------

    readonly property var cel: Logic.celestial(now, wx.sunrise, wx.sunset)

    property real sunX: 0.5
    property real sunY: 0.5
    property real moonX: 0.5
    property real moonY: 0.5
    property real elevation: 0
    property bool snap: true    // true = assign without animating
    property bool ready: false

    // 60 s linear glide turns the minute ticks into continuous motion
    Behavior on sunX { enabled: !root.snap; NumberAnimation { duration: 60000 } }
    Behavior on sunY { enabled: !root.snap; NumberAnimation { duration: 60000 } }
    Behavior on moonX { enabled: !root.snap; NumberAnimation { duration: 60000 } }
    Behavior on moonY { enabled: !root.snap; NumberAnimation { duration: 60000 } }
    Behavior on elevation { enabled: !root.snap; NumberAnimation { duration: 60000 } }

    function applyCel() {
        const c = cel;
        // big jump (midnight wrap, preview hour change): don't sweep across the screen
        const jump = Math.max(Math.abs(c.sunX - sunX), Math.abs(c.sunY - sunY),
                              Math.abs(c.moonX - moonX), Math.abs(c.moonY - moonY),
                              Math.abs(c.elevation - elevation));
        snap = !ready || jump > 0.3;
        sunX = c.sunX;
        sunY = c.sunY;
        moonX = c.moonX;
        moonY = c.moonY;
        elevation = c.elevation;
        snap = false;
    }
    onCelChanged: applyCel()
    // ready flips after every child's onCompleted (Weather cache parse), so startup does not crossfade
    Component.onCompleted: {
        appliedPreview = previewWeather;
        applyCel();
        Qt.callLater(function () { root.ready = true; root.logPause("startup"); });
    }

    readonly property var sky: Logic.skyColors(elevation, clouds)
    readonly property real light: Logic.sceneLight(elevation, clouds)

    // night indigo-grey to cream-white by light, plus a sakura/peach cast in the golden window at the horizon
    readonly property color cloudTint: {
        const lit = Qt.tint("#3a4170", Qt.rgba(0.984, 0.965, 0.914, light));   // #fbf6e9
        const warm = Math.max(0, 1 - Math.abs(elevation - 0.03) / 0.12);
        return Qt.tint(lit, Qt.rgba(0.965, 0.706, 0.604, warm));   // #f6b49a
    }

    // creamy mist by day (cream tinted by the sky), #5a6478 at night
    readonly property color fogColor: Qt.tint("#5a6478", Qt.alpha(Qt.tint("#efe6cf", Qt.alpha(sky.bottom, 0.25)), light))

    // ---- scene --------------------------------------------------------

    Sky {
        anchors.fill: parent
        topColor: root.sky.top
        bottomColor: root.sky.bottom
        bandColor: root.sky.band
        horizonColor: root.sky.horizon
        horizonAlpha: root.sky.horizonAlpha
        sunX: root.sunX
        sunY: root.sunY
        moonX: root.moonX
        moonY: root.moonY
        sunVisible: root.cel.sunVisible
        moonVisible: root.cel.moonVisible
        moonPhase: Logic.moonPhase(root.now)
        starOpacity: root.cel.starOpacity * (1 - root.clouds)
        running: root.active
    }

    Clouds {
        anchors.fill: parent
        cover: root.clouds
        darkness: Math.max(root.storm, root.rain * 0.5)
        windX: root.windX
        tint: root.cloudTint
        running: root.active
    }

    Landscape {
        anchors.fill: parent
        colors: Logic.season(root.now, root.configuration.Latitude)
        light: root.light
        snowCap: Logic.snowCap(root.now, root.configuration.Latitude)
        ink: Logic.INK
        windX: root.windX
        running: root.active
    }

    Life {
        anchors.fill: parent
        month: (root.now.getMonth() + (root.configuration.Latitude < 0 ? 6 : 0)) % 12
        light: root.light
        windX: root.windX
        precip: Math.max(root.rain, root.snow)
        running: root.active
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.height * 0.6
        opacity: root.fog * 0.85
        visible: opacity > 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(root.fogColor, 0) }
            GradientStop { position: 0.6; color: root.fogColor }
            GradientStop { position: 1.0; color: root.fogColor }
        }
    }

    Precipitation {
        anchors.fill: parent
        rain: root.rain
        snow: root.snow
        windX: root.windX
        running: root.active
    }

    Rectangle {
        id: flash
        anchors.fill: parent
        color: "white"
        opacity: 0
        visible: opacity > 0

        SequentialAnimation {
            id: flashAnim
            onStopped: flash.opacity = 0

            NumberAnimation { target: flash; property: "opacity"; to: 0.55; duration: 60 }
            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 120 }
            NumberAnimation { target: flash; property: "opacity"; to: 0.35; duration: 50 }
            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 300 }
        }
    }

    // random gap between bolts; the interval is set from the handler, never from inside an animation
    Timer {
        id: boltTimer
        repeat: false
        running: root.storm > 0.3 && root.active
        interval: 8000
        onTriggered: {
            flashAnim.restart();
            interval = 6000 + Math.random() * 14000;
            restart();
        }
    }

    // washi grain on top of everything (not interactive)
    Paper {
        anchors.fill: parent
        strength: 0.55
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
            onCoversChanged: {
                Qt.callLater(root.recount);
                if (covers)
                    console.log("Wallscreen cover changed: title=" + model.display
                        + " IsMaximized=" + model.IsMaximized + " IsFullScreen=" + model.IsFullScreen);
            }
        }
    }

    readonly property bool active:
        !(configuration.PauseOnBattery && onBattery)
        && !(configuration.PauseWhenCovered && covered)

    function logPause(tag) {
        console.log("Wallscreen " + tag + " active=" + active + " onBattery=" + onBattery + " covered=" + covered
            + " count=" + coveredCount + " showingDesktop=" + KWindowSystem.showingDesktop
            + " geom=" + JSON.stringify(tasks.screenGeometry) + " filterByScreen=" + tasks.filterByScreen);
    }
    onActiveChanged: logPause("active changed")
}

import QtQuick
import "../" as Nexa

Item {
    id: root

    function findFlickable(item) {
        var p = item ? item.parent : null
        while (p) {
            if (p.contentY !== undefined && p.flick !== undefined) {
                return p
            }
            p = p.parent
        }
        return null
    }

    readonly property Flickable flickable: findFlickable(root)
    property bool horizontal: false

    // Geometry matches the visible viewport of the Flickable so WheelHandler covers the full interactive area
    x: flickable ? flickable.contentX : 0
    y: flickable ? flickable.contentY : 0
    width: flickable ? flickable.width : 0
    height: flickable ? flickable.height : 0
    z: 9999

    // Mouse wheel notch settings
    property real wheelStepSize: 160.0
    property real wheelResponseSpeed: 24.0
    property real targetOffset: 0
    property real lastWheelTime: 0

    // Touchpad kinetic physics settings
    property real touchpadMultiplier: 1.5
    property real touchpadFriction: 3.2
    property real touchVelocity: 0
    property var touchSamples: []
    property real lastFrameTime: 0

    Component.onCompleted: {
        console.log("SmoothScroll active, flickable =", flickable, "width =", root.width, "height =", root.height)
        if (flickable) {
            flickable.pixelAligned = false
            flickable.flickDeceleration = Nexa.Theme ? Nexa.Theme.flickDeceleration : 700
            flickable.maximumFlickVelocity = Nexa.Theme ? Nexa.Theme.flickVelocityMax : 4500
            targetOffset = root.horizontal ? flickable.contentX : flickable.contentY
        }
    }

    // ── High-FPS VSYNC Animation Driver ──────────────────────────────────────
    FrameAnimation {
        id: frameDriver
        running: false

        onTriggered: {
            if (!root.flickable) {
                running = false
                return
            }

            let dt = frameTime - root.lastFrameTime
            root.lastFrameTime = frameTime
            if (dt <= 0 || dt > 0.05) dt = 0.016

            // Mode A: Touchpad Kinetic Glide (Momentum after fingers lift)
            if (Math.abs(root.touchVelocity) > 0) {
                const moveStep = root.touchVelocity * dt
                root.touchVelocity *= Math.exp(-root.touchpadFriction * dt)

                if (root.horizontal) {
                    const minX = root.flickable.originX
                    const maxX = Math.max(minX, root.flickable.originX + root.flickable.contentWidth - root.flickable.width)
                    const nextX = Math.max(minX, Math.min(maxX, root.flickable.contentX - moveStep))
                    root.flickable.contentX = nextX
                    root.targetOffset = nextX

                    if (nextX <= minX || nextX >= maxX || Math.abs(root.touchVelocity) < 12) {
                        root.touchVelocity = 0
                        running = false
                    }
                } else {
                    const minY = root.flickable.originY
                    const maxY = Math.max(minY, root.flickable.originY + root.flickable.contentHeight - root.flickable.height)
                    const nextY = Math.max(minY, Math.min(maxY, root.flickable.contentY - moveStep))
                    root.flickable.contentY = nextY
                    root.targetOffset = nextY

                    if (nextY <= minY || nextY >= maxY || Math.abs(root.touchVelocity) < 12) {
                        root.touchVelocity = 0
                        running = false
                    }
                }
                return
            }

            // Mode B: Mouse Wheel Smooth Exponential Interpolation
            const current = root.horizontal ? root.flickable.contentX : root.flickable.contentY
            const target = root.targetOffset
            const diff = target - current

            if (Math.abs(diff) < 0.25) {
                if (root.horizontal) {
                    root.flickable.contentX = target
                } else {
                    root.flickable.contentY = target
                }
                running = false
                return
            }

            const factor = 1.0 - Math.exp(-root.wheelResponseSpeed * dt)
            const nextPos = current + (diff * factor)

            if (root.horizontal) {
                root.flickable.contentX = nextPos
            } else {
                root.flickable.contentY = nextPos
            }
        }
    }

    WheelHandler {
        id: wheelHandler
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            if (!root.flickable) return

            const now = Date.now()

            // ────────────────────────────────────────────────────────
            // PATH 1: TOUCHPAD TWO-FINGER SCROLLING (PixelDelta or Gesture Phase)
            // ────────────────────────────────────────────────────────
            const hasPixelDelta = root.horizontal
                ? (event.pixelDelta.x !== 0 || (event.pixelDelta.y !== 0 && event.angleDelta.x === 0))
                : (event.pixelDelta.y !== 0)

            const isTouchpad = hasPixelDelta || (event.phase !== 0 && event.phase !== undefined)

            if (isTouchpad) {
                const rawDelta = root.horizontal
                    ? (event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.pixelDelta.y)
                    : event.pixelDelta.y

                const scaledDelta = rawDelta * root.touchpadMultiplier

                // Phase 1: Touch Start -> halt any existing momentum immediately
                if (event.phase === 1) {
                    root.touchVelocity = 0
                    root.touchSamples = []
                    frameDriver.running = false
                    event.accepted = true
                    return
                }

                // Phase 2 (or active pixel motion): Fingers moving on touchpad
                if (event.phase === 2 || rawDelta !== 0) {
                    frameDriver.running = false
                    root.touchVelocity = 0

                    if (scaledDelta !== 0) {
                        // Apply movement directly with 1:1 finger tracking
                        if (root.horizontal) {
                            const minX = root.flickable.originX
                            const maxX = Math.max(minX, root.flickable.originX + root.flickable.contentWidth - root.flickable.width)
                            const nextX = Math.max(minX, Math.min(maxX, root.flickable.contentX - scaledDelta))
                            root.flickable.contentX = nextX
                            root.targetOffset = nextX
                        } else {
                            const minY = root.flickable.originY
                            const maxY = Math.max(minY, root.flickable.originY + root.flickable.contentHeight - root.flickable.height)
                            const nextY = Math.max(minY, Math.min(maxY, root.flickable.contentY - scaledDelta))
                            root.flickable.contentY = nextY
                            root.targetOffset = nextY
                        }

                        // Store sample in sliding history for accurate exit velocity
                        root.touchSamples.push({ t: now, d: scaledDelta })
                        const cutoff = now - 90
                        while (root.touchSamples.length > 0 && root.touchSamples[0].t < cutoff) {
                            root.touchSamples.shift()
                        }
                    }
                    event.accepted = true
                    return
                }

                // Phase 3: Touch End (Fingers lifted) -> launch kinetic coasting
                if (event.phase === 3) {
                    const samples = root.touchSamples
                    if (samples && samples.length >= 2) {
                        let totalD = 0
                        for (let i = 0; i < samples.length; i++) {
                            totalD += samples[i].d
                        }
                        const dt = (samples[samples.length - 1].t - samples[0].t) / 1000.0
                        const elapsedSinceLast = now - samples[samples.length - 1].t

                        if (dt > 0.015 && elapsedSinceLast < 80) {
                            const exitV = totalD / dt
                            if (Math.abs(exitV) > 50) {
                                root.touchVelocity = exitV
                                root.lastFrameTime = 0
                                frameDriver.running = true
                                console.log("Touchpad fling launched, exit velocity =", exitV.toFixed(1))
                            }
                        }
                    }
                    root.touchSamples = []
                    event.accepted = true
                    return
                }
            }

            // ────────────────────────────────────────────────────────
            // PATH 2: TRADITIONAL NOTCHED MOUSE WHEEL
            // ────────────────────────────────────────────────────────
            const aDelta = root.horizontal
                ? (event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y)
                : event.angleDelta.y

            if (aDelta !== 0) {
                root.touchVelocity = 0
                root.touchSamples = []

                const notches = aDelta / 120.0
                const timeDiff = now - root.lastWheelTime
                root.lastWheelTime = now

                let boost = 1.0
                if (timeDiff < 90 && timeDiff > 0) boost = 1.45
                else if (timeDiff < 140 && timeDiff > 0) boost = 1.2

                const distance = notches * root.wheelStepSize * boost

                if (root.horizontal) {
                    const minX = root.flickable.originX
                    const maxX = Math.max(minX, root.flickable.originX + root.flickable.contentWidth - root.flickable.width)
                    const currentTarget = frameDriver.running ? root.targetOffset : root.flickable.contentX
                    root.targetOffset = Math.max(minX, Math.min(maxX, currentTarget - distance))
                } else {
                    const minY = root.flickable.originY
                    const maxY = Math.max(minY, root.flickable.originY + root.flickable.contentHeight - root.flickable.height)
                    const currentTarget = frameDriver.running ? root.targetOffset : root.flickable.contentY
                    root.targetOffset = Math.max(minY, Math.min(maxY, currentTarget - distance))
                }

                if (!frameDriver.running) {
                    root.lastFrameTime = 0
                    frameDriver.running = true
                }
                event.accepted = true
            }
        }
    }
}

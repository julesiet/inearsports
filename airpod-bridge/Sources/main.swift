// Libraries for Gyroscopic and JSON data
import Foundation
import CoreMotion
import AppKit

print("Starting AirPod motion test...")

let motionManager = CMHeadphoneMotionManager() // Device Object
let queue = OperationQueue() // Task Manager for sensor updates (queue)

if motionManager.isDeviceMotionAvailable {

    // Begin delivering measurements to be received
    motionManager.startDeviceMotionUpdates(to: queue) { motion, error in

        // if there is an error
        if let error = error {
            print("Motion error: \(error)")
            return
        }

        // if no error, is this even a valid reasding
        guard let motion = motion else {
            return
        }

        // Identify which airpod was which in the motion detection
        switch motion.sensorLocation {
        case .headphoneLeft:
            print("Sensor: LEFT AirPod")

        case .headphoneRight:
            print("Sensor: RIGHT AirPod")

        default:
            print("Sensor: Unknown")
}

        // Gets angular velocity on the X, Y, and Z axes, in radians/second.
        let rotation = motion.rotationRate

        // Gets Pitch, Yaw, and Roll of AirPod
        let attitude = motion.attitude

        // Radians returned, give me degrees
        let pitch = attitude.pitch * 180 / .pi  // Forward + Backwards
        let roll = attitude.roll * 180 / .pi    // Tilting Side by Side
        let yaw = attitude.yaw * 180 / .pi      // Turn Left + Right

        print("Pitch: \(pitch), Roll: \(roll), Yaw: \(yaw)")
        print("X: \(rotation.x), Y: \(rotation.y), Z: \(rotation.z)")
        print()
    }

    print("Listening for AirPod movement...")

    // run the damn app with the permissions apple
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.run()

} else {
    print("Headphone motion unavailable.")
}

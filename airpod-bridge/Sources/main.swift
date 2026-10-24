// Libraries for Gyroscopic and JSON data
import Foundation
import CoreMotion
import AppKit

print("Starting AirPod motion test...")

/*
// fake hard coded packet
let testPacket = MotionPacket(
    version: 1,
    stream_id: "test-session",
    sequence: 1,
    sensor_time_s: 0.5,
    orientation: QuaternionPacket(
        x: 0.1, y: 0.2, z: 0.3, w: 0.9
    ),
    rotation_rate: Vector3Packet(
        x: 0.5, y: 1.2, z: 0.1
    )
)

// makes swift objects into JSON data
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted

do {
    let jsonData = try encoder.encode(testPacket)
    print(String(decoding: jsonData, as: UTF8.self))
} catch {
    print("JSON encoding failed: \(error)")
}
*/

let motionManager = CMHeadphoneMotionManager() // Device Object
let queue = OperationQueue() // Task Manager for sensor updates (queue)

// starts UDP sender for JSON data 
let udpSender = LocalUDPSender()
udpSender.start()

// process a packet at a time
queue.maxConcurrentOperationCount = 1 
var sequenceNumber = 0

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

        sequenceNumber += 1

        let streamID = UUID().uuidString

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

        // Quaternion representing the AirPods' orientation in 3D space
        let quaternion = motion.attitude.quaternion

        // formats each packet using the airpod data
        let packet = MotionPacket(
            version: 1,
            stream_id: streamID,
            sequence: sequenceNumber,
            sensor_time_s: motion.timestamp,

            orientation: QuaternionPacket(
                x: quaternion.x,
                y: quaternion.y,
                z: quaternion.z,
                w: quaternion.w
            ),

            rotation_rate: Vector3Packet(
                x: rotation.x,
                y: rotation.y,
                z: rotation.z
            )
        )

        // JSON packaging and sending
        let encoder = JSONEncoder()

        do {
            let jsonData = try encoder.encode(packet)
            udpSender.send(jsonData)

        } catch {
            print("JSON encoding failed: \(error)")
        }

        
        // Gets Pitch, Yaw, and Roll of AirPod
        let attitude = motion.attitude

        // Radians returned, give me degrees
        let pitch = attitude.pitch * 180 / .pi  // Forward + Backwards
        let roll = attitude.roll * 180 / .pi    // Tilting Side by Side
        let yaw = attitude.yaw * 180 / .pi      // Turn Left + Right

        //print("Pitch: \(pitch), Roll: \(roll), Yaw: \(yaw)")
        //print("X: \(rotation.x), Y: \(rotation.y), Z: \(rotation.z)")
        //print()
    }

    print("Listening for AirPod movement...")

    // run the damn app with the permissions apple
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.run()

} else {
    print("Headphone motion unavailable.")
}

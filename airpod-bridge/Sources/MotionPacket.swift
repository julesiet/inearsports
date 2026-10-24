import Foundation
/*
Format of Json
{
  "orientation": {
    "x": 0.1,
    "y": 0.2,
    "z": 0.3,
    "w": 0.9
  },
  "rotation_rate": {
    "x": 0.5,
    "y": 1.2,
    "z": 0.1
  }
}
*/

// x, y, z packet
struct Vector3Packet: Encodable {
    let x: Double
    let y: Double
    let z: Double
}

// four orientation values
struct QuaternionPacket: Encodable {
    let x: Double
    let y: Double
    let z: Double
    let w: Double
}

// groups all the information Godot will receive as a JSON
struct MotionPacket: Encodable {
    let version: Int
    let stream_id: String
    let sequence: Int
    let sensor_time_s: Double

    let orientation: QuaternionPacket
    let rotation_rate: Vector3Packet
}

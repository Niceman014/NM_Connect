<div align="center">

# 🟢 NM Connect

**Ultra-Low Latency, High-Security Remote Desktop & Screen Sharing.**

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-43853D?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
[![WebRTC](https://img.shields.io/badge/WebRTC-333333?style=for-the-badge&logo=webrtc&logoColor=white)](https://webrtc.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

*Connect securely. Control seamlessly. Free for everyone, forever.*

</div>

---

## 📖 Overview

**NM Connect** is a production-grade, open-source remote desktop application designed to provide **ultra-low latency** screen sharing and remote control. Built with a hybrid architecture using **Flutter** for the cross-platform UI, **Node.js** for blazing-fast signaling, and **WebRTC** for peer-to-peer (P2P) media streaming.

Unlike other remote tools, NM Connect routes your video and input data directly between devices (P2P), meaning your screen data never touches our servers.

## ✨ Features

- ⚡ **Ultra-Low Latency:** Powered by WebRTC, achieving sub-100ms latency on local networks.
- 🔒 **End-to-End Encryption:** All media and data streams are encrypted via DTLS-SRTP natively.
- 🆔 **Unique 9-Digit ID:** Easy-to-share, auto-generated device IDs (like AnyDesk/TeamViewer).
- 🖥️ **Multi-Platform:** Built to support Windows, macOS, Linux, Android, and iOS (Windows-to-Windows currently implemented).
- 🎛️ **Quality Presets:** Supports 720p, 1080p, and 1440p at 30/60 FPS (adaptive bitrate planned).
- 🛡️ **Privacy First:** Requires explicit host approval for every connection. No auto-accept.

---

## 🏗️ Architecture

NM Connect uses a decentralized P2P architecture. The Node.js server is only used for the initial "handshake" (Signaling). Once connected, the video and data flow directly between the devices.

```mermaid
sequenceDiagram
    participant Viewer as Viewer (Client B)
    participant Server as Signaling Server (Node.js)
    participant Host as Host (Client A)

    Viewer->>Server: register(Device ID)
    Host->>Server: register(Device ID)
    
    Viewer->>Server: connect-request(to Host)
    Server->>Host: forward(connect-request)
    Host-->>Server: connect-response(accepted)
    Server->>Viewer: forward(connect-response)
    
    Note over Viewer,Host: WebRTC Handshake (SDP / ICE) via Server
    
    Host->>Viewer: P2P WebRTC Video Stream (DTLS-SRTP Encrypted)
    Viewer->>Host: P2P Data Channel (Mouse/Keyboard)
# Garmin Bluetooth Protocol Specification

> Based on reverse-engineering of Garmin Connect Mobile APK
> Last Updated: 2026-05-01

---

## 1. Bluetooth UUIDs

### 1.1 Standard Bluetooth SIG UUIDs

| UUID | Service/Characteristic | Description |
|------|------------------------|-------------|
| `00001801-0000-1000-8000-00805F9B34FB` | Generic Attribute (GATT) | GAP service |
| `0000180A-0000-1000-8000-00805F9B34FB` | Device Information | Device info |
| `00001810-0000-1000-8000-00805F9B34FB` | **Garmin Fitness Service** | Fitness data |
| `00001818-0000-1000-8000-00805f9b34fb` | Unknown | Unknown |
| `00002A05-0000-1000-8000-00805F9B34FB` | Service Changed | GATT state |

### 1.2 Garmin Custom UUIDs

Base prefix: `6A4E####-667B-11E3-949A-0800200C9A66`

| UUID | Description | Type |
|------|-------------|------|
| `0000FE1F-0000-1000-8000-00805F9B34FB` | **Unified Garmin Service** | Service |
| `6A4E8022-...` | Navigation Write | **Characteristic** |
| `6A4E4C80-...` | Navigation Data | Characteristic |
| `6A4ECD28-...` | Route/Path Data | Characteristic |
| `6A4E564B-...` | POI Data | Characteristic |
| `6A4E2500-...` | Real-time Data Notify | Characteristic |
| `6A4E2501-...` | Heart Rate | Characteristic |
| `6A4E2502-...` | Steps | Characteristic |
| `6A4E2503-...` | Calories | Characteristic |
| `6A4E2800-...` | Multi-Link Register Response | Characteristic |
| `6A4E2803-...` | Multi-Link Data Channel | Characteristic |

---

## 2. Connection Flow

```
1. BluetoothAdapter.getDefaultAdapter()
2. BluetoothLeScanner.startScan() — filter by name or service UUID
3. Select device, call BluetoothDevice.connectGatt()
4. gatt.discoverServices()
5. Find Unified Garmin Service (0000FE1F)
6. Get characteristic by UUID (6A4E8022 for navigation write)
7. characteristic.writeWithValue(data) — write route data
8. gatt.disconnect()
```

### 2.1 Scanning Filter

```dart
// Filter devices with "GARMIN", "Fenix", "Forerunner", "Edge" in name
// Or filter by service UUID: 0000FE1F
ScanFilter Builder.setServiceUuid(ParcelUuid.fromString('0000FE1F-...'))
```

### 2.2 MTU Negotiation

- Default BLE MTU: 23 bytes
- Negotiated MTU (Android): typically 517 bytes
- Actual payload per write: MTU - 3 bytes (ATT header)

---

## 3. Navigation Data Format

### 3.1 FIT Protocol Overview

Garmin uses the FIT (Flexible and Interoperable Data Transfer) protocol for route data.

**FIT File Structure:**
```
[Header (14 bytes)]
[Data Records]
[CRC (2 bytes)]
```

### 3.2 Header Format

| Offset | Size | Field | Value |
|--------|------|-------|-------|
| 0 | 1 | Header Size | 14 (0x0E) |
| 1 | 1 | Protocol Version | 0x10 (2.0) |
| 2 | 2 | Profile Minor Version | 0x0006 (little-endian) |
| 4 | 4 | Data Size | (total data bytes, LE) |
| 8 | 4 | ".FIT" Magic | 0x2E 0x46 0x49 0x54 |
| 12 | 2 | Header CRC | (CRC-16-CCITT) |

### 3.3 Coordinate Encoding (Semicircles)

Garmin uses semicircle representation for coordinates:
- `2^31 = 180 degrees`
- To convert: `semicircles = degrees / 180.0 * 2147483648`

### 3.4 Message Types for Routes

| Message | Number | Description |
|---------|--------|-------------|
| `file_id` | 0 | File identification (type=4 for course) |
| `course` | 25 (0x19) | Course metadata |
| `record` | 32 (0x20) | Track points (lat/lon/alt) |
| `course_point` | 27 (0x1B) | Navigation points |

### 3.5 Course Point Types

| Value | Type |
|-------|------|
| 0 | Generic |
| 6 | Left Turn |
| 7 | Right Turn |
| 8 | Straight |
| 9 | First |
| 12 | Finish |

---

## 4. Write Sequence

```dart
// 1. Connect and discover services
await device.connect();
await device.discoverServices();

// 2. Get navigation write characteristic
var service = device.services.firstWhere(
    (s) => s.uuid.toString().contains('0000FE1F'));
var char = service.chars.firstWhere(
    (c) => c.uuid.toString().contains('6A4E8022'));

// 3. Encode route to FIT binary
var routeData = GarminProtocol.encodeRoute(route);

// 4. Split into MTU-sized chunks
var mtu = await device.mtu;
var chunkSize = mtu - 3; // ATT header overhead

for (var offset = 0; offset < routeData.length; offset += chunkSize) {
    var end = min(offset + chunkSize, routeData.length);
    var chunk = routeData.sublist(offset, end);
    
    // 5. Write each chunk with response
    await char.write(chunk, withoutResponse: false);
    
    // Small delay between writes
    await Future.delayed(Duration(milliseconds: 50));
}

// 6. Route now appears on device
```

---

## 5. Device Compatibility

| Device Series | Service UUID | Navigation UUID | Notes |
|---------------|--------------|-----------------|-------|
| Fenix 6/7/8 | 0000FE1F | 6A4E8022 | Fully supported |
| Forerunner 245/255/265/955 | 0000FE1F | 6A4E8022 | Fully supported |
| Edge 530/830/1040 | 0000FE1F | 6A4E8022 | Cycling computers |
| Legacy devices | Unknown | Unknown | May use different UUIDs |

---

## 6. Limitations & Notes

1. **Protocol may vary by firmware version** — Test with specific device
2. **Write requires bonded/paired device** — Pair in system settings first
3. **Large routes may take time** — Each chunk ~500 bytes, ~50ms delay
4. **Android 13+ requires `BLUETOOTH_CONNECT` permission**
5. **This spec is based on reverse-engineering** — Not officially documented

---

## 7. Testing Checklist

- [ ] Device discovered via scan
- [ ] GATT connection established
- [ ] Service 0000FE1F discovered
- [ ] Characteristic 6A4E8022 found
- [ ] Write returns success
- [ ] Route appears in device's course list
- [ ] Navigation starts correctly on device

---

*This document is for educational and development purposes only. Garmin® is a registered trademark of Garmin Ltd.*
require('dotenv').config();
const { initializeApp } = require('firebase/app');
const { getFirestore, collection, doc, addDoc, serverTimestamp } = require('firebase/firestore');

const firebaseConfig = {
  apiKey: process.env.FIREBASE_API_KEY,
  authDomain: process.env.FIREBASE_AUTH_DOMAIN,
  projectId: process.env.FIREBASE_PROJECT_ID,
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.FIREBASE_APP_ID
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

// Simulated device MAC address (used as Firestore document path)
const DEVICE_ID = "SIMULATOR_1";

// starting coords near Aditya University
let lat = 17.5937;
let lng = 82.2600;

console.log('SafeTrack Bus Simulator Started');
console.log('Pushing live data every 5 seconds... (Ctrl+C to stop)');

async function pushSimulatedData() {
  // simulate slight GPS drift each cycle
  lat += (Math.random() - 0.5) * 0.001;
  lng += (Math.random() - 0.5) * 0.001;

  const sensorData = {
    busId: "SIMULATED_BUS_001",
    busNumber: "AP-05-ST-2024",
    deviceId: DEVICE_ID,
    latitude: lat,
    longitude: lng,
    speed: 40 + Math.random() * 20,
    temperature: 25 + Math.random() * 5,
    smoke: "SAFE",
    tiltAngle: "SAFE",
    isEmergency: false,
    timestamp: serverTimestamp()
  };

  try {
    // Write to devices/{deviceId}/readings subcollection (MAC-address-based path)
    const deviceRef = doc(db, 'devices', DEVICE_ID);
    await addDoc(collection(deviceRef, 'readings'), sensorData);
    console.log(`[${new Date().toLocaleTimeString()}] Sent: ${lat.toFixed(4)}, ${lng.toFixed(4)}, ${sensorData.temperature.toFixed(1)}C`);

    // 10% chance of generating a test SPEEDING alert
    if (Math.random() > 0.9) {
      triggerFakeAlert();
    }
  } catch (e) {
    console.error('Error sending data:', e);
  }
}

async function triggerFakeAlert() {
  const alert = {
    busId: "SIMULATED_BUS_001",
    busNumber: "AP-05-ST-2024",
    alertType: "SPEEDING",
    severity: "MEDIUM",
    message: "Bus is exceeding 60km/h safety limit",
    latitude: lat,
    longitude: lng,
    isResolved: false,
    timestamp: new Date().toISOString()
  };

  try {
    await addDoc(collection(db, 'alerts'), alert);
    console.log('ALERT: Speeding detected!');
  } catch (e) {
    console.error('Error triggering alert:', e);
  }
}

setInterval(pushSimulatedData, 5000);
pushSimulatedData();

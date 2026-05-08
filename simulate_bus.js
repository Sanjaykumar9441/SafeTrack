const { initializeApp } = require('firebase/app');
const { getFirestore, collection, addDoc, serverTimestamp } = require('firebase/firestore');

const firebaseConfig = {
  apiKey: "AIzaSyBTrDjbGYfv2vkRBheq4XjLhqY7jUMqEMs",
  authDomain: "safedrive-144.firebaseapp.com",
  projectId: "safedrive-144",
  storageBucket: "safedrive-144.firebasestorage.app",
  messagingSenderId: "915377574101",
  appId: "1:915377574101:web:3ad362dd20cc87e9cdd25c"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

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
    deviceId: "SIMULATOR_1",
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
    await addDoc(collection(db, 'live_data'), sensorData);
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

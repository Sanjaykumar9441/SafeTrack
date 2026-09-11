require('dotenv').config();

const SIMULATOR_MODE = process.env.SIMULATOR_MODE || 'development';
if (SIMULATOR_MODE !== 'development') { console.error('Simulator blocked: set SIMULATOR_MODE=development to run it.'); process.exit(1); }
if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_PROJECT_ID.includes('prod')) { console.error('Refusing to write simulator data to a project name containing "prod".'); process.exit(1); }

const { initializeApp } = require('firebase/app');
const { getFirestore, collection, doc, addDoc, setDoc, serverTimestamp } = require('firebase/firestore');
const firebaseConfig = { apiKey: process.env.FIREBASE_API_KEY, authDomain: process.env.FIREBASE_AUTH_DOMAIN, projectId: process.env.FIREBASE_PROJECT_ID, storageBucket: process.env.FIREBASE_STORAGE_BUCKET, messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID, appId: process.env.FIREBASE_APP_ID };
if (!firebaseConfig.apiKey || !firebaseConfig.projectId) { console.error('Missing Firebase simulator configuration in .env.'); process.exit(1); }

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const DEVICE_ID = process.env.SIMULATOR_DEVICE_ID || 'SIMULATOR_1';
const BUS_ID = process.env.SIMULATOR_BUS_ID || 'SIMULATED_BUS_001';
const BUS_NUMBER = process.env.SIMULATOR_BUS_NUMBER || 'AP-05-ST-2024';
const SEAT_CAPACITY = Number(process.env.SIMULATOR_SEAT_CAPACITY || 4);
const INTERVAL_MS = Number(process.env.SIMULATOR_INTERVAL_MS || 5000);
let lat = Number(process.env.SIMULATOR_LAT || 17.5937);
let lng = Number(process.env.SIMULATOR_LNG || 82.2600);
let tick = 0;

console.log('SafeTrack Bus Simulator Started');
console.log(`Bus: ${BUS_NUMBER} (${BUS_ID})`);
console.log(`Device: ${DEVICE_ID}`);
console.log(`Writing every ${INTERVAL_MS} ms. Ctrl+C to stop.`);

async function ensureSimulatorBus() {
  await setDoc(doc(db, 'buses', BUS_ID), { busNumber: BUS_NUMBER, busName: 'SafeTrack Expo Simulator', seatCapacity: SEAT_CAPACITY, deviceId: DEVICE_ID, safetyStatus: 'SAFE', driverStatus: 'ON_ROUTE', isActive: true, updatedAt: serverTimestamp() }, { merge: true });
}

async function pushSimulatedData() {
  tick += 1;
  lat += (Math.random() - 0.5) * 0.001;
  lng += (Math.random() - 0.5) * 0.001;
  const flameDetected = tick % 37 === 0;
  const smokeDetected = tick % 29 === 0;
  const tiltAngle = tick % 41 === 0 ? 45 + Math.random() * 10 : Math.random() * 8;
  const speed = 40 + Math.random() * 20;
  const seatCount = Math.floor(Math.random() * (SEAT_CAPACITY + 1));
  const sensorData = { busId: BUS_ID, busNumber: BUS_NUMBER, deviceId: DEVICE_ID, latitude: lat, longitude: lng, speed, temperature: 25 + Math.random() * 5, smoke: smokeDetected ? 'ALERT' : 'SAFE', smokeDetected, flameDetected, tiltAngle, seatCount, isEmergency: flameDetected || smokeDetected || tiltAngle > 30, timestamp: serverTimestamp() };

  try {
    await addDoc(collection(doc(db, 'devices', DEVICE_ID), 'readings'), sensorData);
    await addDoc(collection(db, 'live_data'), sensorData);
    console.log(`[${new Date().toLocaleTimeString()}] ${BUS_NUMBER} | ${lat.toFixed(4)}, ${lng.toFixed(4)} | speed ${speed.toFixed(1)} | seats ${seatCount}/${SEAT_CAPACITY} | flame ${flameDetected ? 'ALERT' : 'SAFE'} | smoke ${smokeDetected ? 'ALERT' : 'SAFE'}`);
  } catch (error) { console.error('Error sending simulator data:', error.message); }
}

async function triggerFakeAlert() {
  try {
    await addDoc(collection(db, 'alerts'), { busId: BUS_ID, busNumber: BUS_NUMBER, alertType: 'SPEEDING', severity: 'MEDIUM', message: 'Bus is exceeding the 60 km/h safety limit (simulator).', latitude: lat, longitude: lng, isResolved: false, triggeredBy: 'SIMULATOR', timestamp: serverTimestamp() });
    console.log('Demo alert created.');
  } catch (error) { console.error('Error triggering alert:', error.message); }
}

async function main() {
  await ensureSimulatorBus();
  await pushSimulatedData();
  setInterval(async () => { await pushSimulatedData(); if (tick % 12 === 0) await triggerFakeAlert(); }, INTERVAL_MS);
}

main().catch((error) => { console.error(error); process.exit(1); });

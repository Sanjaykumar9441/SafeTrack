import React, { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';
import { getFunctions, httpsCallable } from 'firebase/functions';
import { FiAlertTriangle, FiCheckCircle, FiClock, FiLogOut, FiMapPin, FiNavigation, FiRefreshCw, FiUsers } from 'react-icons/fi';
import { db } from '../../firebase';
import {
  collection,
  doc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  where,
  addDoc,
} from 'firebase/firestore';
import toast from 'react-hot-toast';

const CLOUD_FUNCTION_URL = 'https://sendemergencyalert-zfpscvkqrq-uc.a.run.app';

const DriverTerminal = () => {
  const navigate = useNavigate();
  const { logout, user: driver } = useAuth();
  const functions = getFunctions();
  const asiaFunctions = getFunctions(undefined, 'asia-south1');

  const bus = useMemo(() => {
    try { return JSON.parse(localStorage.getItem('driver_bus') || 'null'); }
    catch { return null; }
  }, []);

  const [liveData, setLiveData] = useState(null);
  const [routeData, setRouteData] = useState(null);
  const [nextStop, setNextStop] = useState(null);
  const [waitingCount, setWaitingCount] = useState(0);
  const [alerts, setAlerts] = useState([]);
  const [sosActive, setSosActive] = useState(false);
  const [sosLoading, setSosLoading] = useState(false);
  const [sosAlertId, setSosAlertId] = useState(null);
  const [rerouteMsg, setRerouteMsg] = useState('');
  const [rerouteLoading, setRerouteLoading] = useState(false);
  const [driverStatus, setDriverStatus] = useState('ON_ROUTE');
  const [time, setTime] = useState(new Date());

  useEffect(() => { const timer = setInterval(() => setTime(new Date()), 1000); return () => clearInterval(timer); }, []);

  useEffect(() => {
    if (!bus?.id) return undefined;
    const q = query(collection(db, 'live_data'), where('busId', '==', bus.id), orderBy('timestamp', 'desc'), limit(1));
    return onSnapshot(q, (snap) => { if (!snap.empty) setLiveData({ id: snap.docs[0].id, ...snap.docs[0].data() }); }, console.error);
  }, [bus]);

  useEffect(() => {
    if (!bus?.id) return undefined;
    const q = query(collection(db, 'routes'), where('busId', '==', bus.id), limit(1));
    return onSnapshot(q, (snap) => {
      if (snap.empty) { setRouteData(null); setNextStop(null); return; }
      const route = { id: snap.docs[0].id, ...snap.docs[0].data() };
      setRouteData(route);
      const stops = Array.isArray(route.intermediateStops) ? route.intermediateStops : [];
      setNextStop(stops[0] || null);
    });
  }, [bus]);

  useEffect(() => {
    if (!bus?.id) return undefined;
    return onSnapshot(doc(db, 'buses', bus.id), (snap) => {
      if (snap.exists()) setDriverStatus(snap.data().driverStatus || 'ON_ROUTE');
    });
  }, [bus]);

  useEffect(() => {
    if (!bus?.id || !nextStop?.name) { setWaitingCount(0); return undefined; }
    const q = query(collection(db, 'stop_waiting'), where('stopName', '==', nextStop.name), where('busId', '==', bus.id), limit(1));
    return onSnapshot(q, (snap) => setWaitingCount(snap.empty ? 0 : Number(snap.docs[0].data().count || 0)));
  }, [bus, nextStop]);

  useEffect(() => {
    if (!bus?.id) return undefined;
    const q = query(collection(db, 'alerts'), where('busId', '==', bus.id), where('isResolved', '==', false), orderBy('timestamp', 'desc'), limit(10));
    return onSnapshot(q, (snap) => {
      const next = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      setAlerts(next);
      const manual = next.find((a) => a.alertType === 'MANUAL_SOS');
      setSosActive(Boolean(manual));
      setSosAlertId(manual?.id || null);
    }, console.error);
  }, [bus]);

  const callEmergencyFunction = async (alert) => {
    const response = await fetch(CLOUD_FUNCTION_URL, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        alertId: alert.id, alertType: alert.alertType || 'EMERGENCY', busNumber: alert.busNumber || bus?.busNumber || 'Unknown',
        severity: alert.severity || 'CRITICAL', latitude: Number(alert.latitude || 0), longitude: Number(alert.longitude || 0),
        message: alert.message || 'Emergency detected',
      }),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok || !data.success) throw new Error(data.error || 'Emergency notification service failed');
    return data;
  };

  const handleSOS = async () => {
    if (!bus?.id || sosActive || sosLoading) return;
    if (!window.confirm('🚨 MANUAL SOS\n\nThis will create a CRITICAL emergency alert and send the configured SafeTrack notifications.\n\nConfirm SOS?')) return;
    setSosLoading(true);
    try {
      const existingQuery = query(collection(db, 'alerts'), where('busId', '==', bus.id), where('alertType', '==', 'MANUAL_SOS'), where('isResolved', '==', false), limit(1));
      const existing = await getDocs(existingQuery);
      if (!existing.empty) { setSosActive(true); setSosAlertId(existing.docs[0].id); toast('An SOS is already active for this bus.'); return; }

      const alert = {
        busId: bus.id, busNumber: bus.busNumber || 'Unknown', alertType: 'MANUAL_SOS', severity: 'CRITICAL',
        message: `Manual SOS triggered by driver ${driver?.name || 'driver'} on bus ${bus.busNumber || 'Unknown'}`,
        latitude: Number(liveData?.latitude || 0), longitude: Number(liveData?.longitude || 0), isResolved: false,
        emergencyAlertSent: false, triggeredBy: 'DRIVER', driverId: driver?.uid || '', driverName: driver?.name || driver?.displayName || 'Driver', timestamp: serverTimestamp(),
      };
      const created = await addDoc(collection(db, 'alerts'), alert);
      const createdAlert = { id: created.id, ...alert };
      await updateDoc(doc(db, 'buses', bus.id), { safetyStatus: 'DANGER', updatedAt: serverTimestamp() });
      setSosActive(true); setSosAlertId(created.id);

      try {
        const result = await callEmergencyFunction(createdAlert);
        const errors = result.results?.errors || [];
        await updateDoc(doc(db, 'alerts', created.id), {
          emergencyAlertSent: errors.length === 0, emergencyAlertSentAt: serverTimestamp(), notificationResult: result.results || null,
          ...(errors.length ? { notificationError: errors.join('; ') } : {}),
        });
        if (errors.length) toast.error(`SOS saved. ${errors.length} notification issue(s). Check Admin → Alerts.`);
        else toast.success('SOS sent. Admin dashboard and configured notifications have been updated.');
      } catch (notificationError) {
        await updateDoc(doc(db, 'alerts', created.id), { emergencyAlertSent: false, notificationError: notificationError.message });
        toast.error(`SOS saved, but notification dispatch failed: ${notificationError.message}`);
      }
    } catch (err) { toast.error(`SOS failed: ${err.message}`); }
    finally { setSosLoading(false); }
  };

  const cancelSOS = async () => {
    if (!bus?.id) return;
    try {
      const q = query(collection(db, 'alerts'), where('busId', '==', bus.id), where('alertType', '==', 'MANUAL_SOS'), where('isResolved', '==', false));
      const snap = await getDocs(q);
      await Promise.all(snap.docs.map((item) => updateDoc(doc(db, 'alerts', item.id), { isResolved: true, resolvedBy: driver?.name || 'driver', resolvedAt: serverTimestamp() })));
      await updateDoc(doc(db, 'buses', bus.id), { safetyStatus: 'SAFE', updatedAt: serverTimestamp() });
      setSosActive(false); setSosAlertId(null); toast.success('SOS cancelled and bus safety status restored to SAFE.');
    } catch (err) { toast.error(`Cancel failed: ${err.message}`); }
  };

  const handleReroute = async () => {
    setRerouteLoading(true); setRerouteMsg('');
    try {
      const generateRouteAdvice = httpsCallable(asiaFunctions, 'generateRouteAdvice');
      const result = await generateRouteAdvice({ currentLocation: nextStop?.name || 'Unknown', destination: routeData?.destination || 'Unknown', nextStop: nextStop?.name || 'Unknown' });
      setRerouteMsg(result.data?.advice || 'No rerouting advice returned.');
    } catch (err) { console.error(err); setRerouteMsg('AI rerouting unavailable. Continue on the current route safely.'); }
    finally { setRerouteLoading(false); }
  };

  const updateDriverStatus = async (status) => {
    if (!bus?.id) return;
    try { await updateDoc(doc(db, 'buses', bus.id), { driverStatus: status, updatedAt: serverTimestamp() }); setDriverStatus(status); toast.success(`Driver status: ${status}`); }
    catch (err) { toast.error(`Failed to update status: ${err.message}`); }
  };

  const handleLogout = async () => { await logout(); localStorage.removeItem('driver_bus'); navigate('/login'); };
  const formatTime = (value) => value.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', second: '2-digit' });

  if (!bus) return (
    <div className="min-h-screen bg-gray-950 text-white flex items-center justify-center p-6">
      <div className="bg-gray-900 border border-gray-800 rounded-2xl p-8 max-w-md text-center">
        <FiAlertTriangle className="w-10 h-10 mx-auto text-yellow-400 mb-4" /><h1 className="text-xl font-bold">No bus selected</h1>
        <p className="text-gray-400 mt-2">Select your assigned bus before opening the driver terminal.</p>
        <button onClick={() => navigate('/driver/bus-select')} className="mt-6 px-5 py-3 rounded-xl bg-yellow-400 text-gray-950 font-semibold">Select Bus</button>
      </div>
    </div>
  );

  const smokeAlert = liveData?.smokeDetected === true || liveData?.smoke === 'ALERT';
  const flameAlert = liveData?.flameDetected === true;
  const crashAlert = liveData?.isEmergency === true || Number(liveData?.tiltAngle || 0) > 30;

  return (
    <div className="min-h-screen bg-gray-950 text-white p-4 lg:p-6">
      <div className="flex items-center justify-between mb-6">
        <div><p className="text-yellow-400 text-xs uppercase tracking-widest">SafeTrack Driver</p><h1 className="text-2xl font-bold">{bus.busNumber || 'Bus'}</h1><p className="text-gray-400 text-sm">{driver?.name || 'Driver'}</p></div>
        <div className="flex items-center gap-4"><div className="hidden sm:block text-right"><p className="font-mono text-xl font-bold">{formatTime(time)}</p><p className="text-xs text-gray-500">{driverStatus}</p></div><button onClick={handleLogout} className="p-2 text-gray-400 hover:text-white" title="Logout"><FiLogOut /></button></div>
      </div>

      {sosActive && <div className="bg-red-950 border border-red-500 rounded-2xl p-4 mb-6 flex flex-col sm:flex-row sm:items-center justify-between gap-3"><div className="flex items-center gap-3"><FiAlertTriangle className="text-red-400 w-7 h-7" /><div><p className="font-bold text-red-300">SOS ACTIVE</p><p className="text-red-400 text-sm">Emergency alert is visible to the admin dashboard.</p>{sosAlertId && <p className="text-red-500 text-xs mt-1">Alert ID: {sosAlertId}</p>}</div></div><button onClick={cancelSOS} className="px-4 py-2 bg-red-600 hover:bg-red-500 rounded-lg font-semibold">Cancel SOS</button></div>}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <section className="bg-gray-900 border border-gray-800 rounded-2xl p-5"><div className="flex items-center gap-2 mb-4"><FiNavigation className="text-green-400" /><h2 className="font-semibold">Live Status</h2></div><div className="grid grid-cols-2 gap-3"><Metric label="Speed" value={`${Number(liveData?.speed || 0).toFixed(1)} km/h`} /><Metric label="Temperature" value={`${Number(liveData?.temperature || 0).toFixed(1)} °C`} /><StatusMetric label="Flame" danger={flameAlert} value={flameAlert ? 'ALERT' : 'SAFE'} /><StatusMetric label="Smoke" danger={smokeAlert} value={smokeAlert ? 'ALERT' : 'SAFE'} /><StatusMetric label="Crash/Tilt" danger={crashAlert} value={crashAlert ? 'ALERT' : 'SAFE'} /><Metric label="Seats" value={`${Number(liveData?.seatCount || 0)} / ${Number(bus.seatCapacity || 0)}`} /></div><p className="text-xs text-gray-500 mt-4">Last update: {liveData?.timestamp?.toDate ? liveData.timestamp.toDate().toLocaleTimeString() : 'Waiting for IoT data'}</p></section>

        <section className="bg-gray-900 border border-gray-800 rounded-2xl p-5"><div className="flex items-center gap-2 mb-4"><FiMapPin className="text-yellow-400" /><h2 className="font-semibold">Route</h2></div><p className="text-2xl font-bold">{nextStop?.name || 'No next stop'}</p><p className="text-gray-400 text-sm mt-1">{routeData?.source || '—'} → {routeData?.destination || '—'}</p><div className="mt-5 bg-gray-800 rounded-xl p-4 flex items-center gap-3"><FiUsers className="text-blue-400 w-6 h-6" /><div><p className="text-2xl font-bold">{waitingCount}</p><p className="text-gray-400 text-xs">Passengers waiting</p></div></div><div className="flex gap-2 mt-4">{['ON_ROUTE', 'AT_STOP', 'OFF_DUTY'].map((status) => <button key={status} onClick={() => updateDriverStatus(status)} className={`px-2 py-1 rounded-lg text-xs ${driverStatus === status ? 'bg-yellow-400 text-gray-950' : 'bg-gray-800 text-gray-400'}`}>{status.replace('_', ' ')}</button>)}</div></section>

        <section className="bg-gray-900 border border-gray-800 rounded-2xl p-5"><div className="flex items-center gap-2 mb-4"><FiAlertTriangle className="text-red-400" /><h2 className="font-semibold">Emergency Control</h2></div><button onClick={handleSOS} disabled={sosActive || sosLoading} className={`w-full py-5 rounded-2xl font-black text-xl ${sosActive || sosLoading ? 'bg-gray-700 text-gray-500 cursor-not-allowed' : 'bg-red-600 hover:bg-red-500 text-white'}`}>{sosLoading ? 'SENDING SOS…' : sosActive ? 'SOS ACTIVE' : '🚨 SEND SOS'}</button><button onClick={handleReroute} disabled={rerouteLoading} className="w-full mt-3 py-3 rounded-xl bg-gray-800 hover:bg-gray-700 text-gray-200 flex items-center justify-center gap-2"><FiRefreshCw className={rerouteLoading ? 'animate-spin' : ''} />{rerouteLoading ? 'Getting advice…' : 'AI Reroute Advice'}</button>{rerouteMsg && <p className="text-sm text-gray-300 bg-gray-800 rounded-xl p-3 mt-3">{rerouteMsg}</p>}</section>
      </div>

      <section className="bg-gray-900 border border-gray-800 rounded-2xl p-5 mt-4"><div className="flex items-center gap-2 mb-4"><FiClock className="text-blue-400" /><h2 className="font-semibold">Active Alerts</h2></div>{alerts.length === 0 ? <div className="flex items-center gap-2 text-green-400"><FiCheckCircle /> No unresolved alerts for this bus.</div> : <div className="space-y-2">{alerts.map((alert) => <div key={alert.id} className={`rounded-xl p-3 ${alert.severity === 'CRITICAL' ? 'bg-red-950 border border-red-700' : 'bg-gray-800'}`}><div className="flex justify-between gap-3"><p className="font-semibold">{alert.alertType} · {alert.severity}</p><span className="text-xs text-gray-500">{alert.id}</span></div><p className="text-sm text-gray-400 mt-1">{alert.message}</p></div>)}</div>}</section>
    </div>
  );
};

const Metric = ({ label, value }) => <div className="bg-gray-800 rounded-xl p-3"><p className="text-xs text-gray-500">{label}</p><p className="font-bold text-lg">{value}</p></div>;
const StatusMetric = ({ label, value, danger }) => <div className="bg-gray-800 rounded-xl p-3"><p className="text-xs text-gray-500">{label}</p><p className={`font-bold text-lg ${danger ? 'text-red-400' : 'text-green-400'}`}>{value}</p></div>;

export default DriverTerminal;

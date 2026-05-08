import React, { useState, useEffect, useRef, useCallback } from 'react';
import { FiAlertTriangle, FiFilter, FiRefreshCw } from 'react-icons/fi';
import { db } from '../../firebase';
import { collection, onSnapshot, query, orderBy, doc, updateDoc, serverTimestamp } from 'firebase/firestore';
import AlertCard from './AlertCard';
import toast from 'react-hot-toast';

// cloud function endpoint for emergency notifications (Twilio + Slack + Telegram)
const CLOUD_FUNCTION_URL = "https://sendemergencyalert-zfpscvkqrq-uc.a.run.app";

const AlertsPanel = () => {
  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [sendingId, setSendingId] = useState(null);
  const processedAlerts = useRef(new Set());
  const isFirstLoad = useRef(true);
  const alertQueue = useRef([]);
  const isProcessingQueue = useRef(false);

  const sendEmergencyAlert = useCallback(async (alert, isAuto = false) => {
    setSendingId(alert.id);
    const toastId = toast.loading(isAuto ? `Auto-alerting for ${alert.alertType}...` : `Sending alert for Bus ${alert.busNumber}...`);
    try {
      const response = await fetch(CLOUD_FUNCTION_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          alertId: alert.id, alertType: alert.alertType || "EMERGENCY",
          busNumber: alert.busNumber || "Unknown", severity: alert.severity || "CRITICAL",
          latitude: alert.latitude || 0, longitude: alert.longitude || 0,
          message: alert.message || "Emergency detected",
        }),
      });
      const data = await response.json();
      if (data.success) {
        const callCount = data.results?.calls?.length || 0;
        const errorCount = data.results?.errors?.length || 0;
        if (errorCount > 0) {
          toast.success(`Partially completed — Calls: ${callCount}. ${errorCount} error(s).`, { id: toastId, duration: 6000 });
        } else {
          toast.success(`Emergency services alerted! Calls: ${callCount}`, { id: toastId, duration: 5000 });
        }
      } else {
        toast.error(`Alert failed: ${data.results?.errors?.join("; ") || "Unknown error"}`, { id: toastId, duration: 8000 });
      }
    } catch (err) {
      toast.error(`Failed to alert services: ${err.message}`, { id: toastId });
    } finally { setSendingId(null); }
  }, []);

  // process queued auto-alerts sequentially with a delay between each
  const processQueue = useCallback(async () => {
    if (isProcessingQueue.current) return;
    isProcessingQueue.current = true;
    while (alertQueue.current.length > 0) {
      const nextAlert = alertQueue.current.shift();
      await sendEmergencyAlert(nextAlert, true);
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
    isProcessingQueue.current = false;
  }, [sendEmergencyAlert]);

  useEffect(() => {
    const alertsQuery = query(collection(db, 'alerts'), orderBy('timestamp', 'desc'));
    const unsubscribe = onSnapshot(alertsQuery, (snapshot) => {
      setAlerts(snapshot.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(false);

      // skip auto-trigger on first load — only react to new docs arriving later
      if (isFirstLoad.current) {
        snapshot.docs.forEach(d => processedAlerts.current.add(d.id));
        isFirstLoad.current = false;
        return;
      }

      // auto-trigger for new CRITICAL/HIGH unresolved alerts
      snapshot.docChanges().forEach((change) => {
        if (change.type === 'added') {
          const newAlert = { id: change.doc.id, ...change.doc.data() };
          if (!processedAlerts.current.has(newAlert.id) && !newAlert.isResolved && ['CRITICAL', 'HIGH'].includes(newAlert.severity)) {
            processedAlerts.current.add(newAlert.id);
            alertQueue.current.push(newAlert);
            setTimeout(() => processQueue(), 1500);
          } else {
            processedAlerts.current.add(newAlert.id);
          }
        }
      });
    }, () => { toast.error('Failed to load alerts'); setLoading(false); });
    return () => unsubscribe();
  }, [processQueue]);

  const handleResolve = async (alertId) => {
    try {
      await updateDoc(doc(db, 'alerts', alertId), { isResolved: true, resolvedBy: 'admin', resolvedAt: serverTimestamp() });
      toast.success('Alert resolved');
    } catch (e) { toast.error('Failed to resolve alert'); }
  };

  const filteredAlerts = filter === 'resolved' ? alerts.filter(a => a.isResolved)
    : filter === 'unresolved' ? alerts.filter(a => !a.isResolved) : alerts;

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Emergency Alerts</h1>
          <p className="text-gray-500 mt-1">Monitor real-time alerts — CRITICAL/HIGH alerts auto-notify emergency services</p>
        </div>
        <div className="flex items-center gap-3">
          <button onClick={() => window.location.reload()} className="flex items-center gap-2 px-3 py-1.5 bg-gray-100 hover:bg-gray-200 text-gray-600 text-sm rounded-lg transition-colors">
            <FiRefreshCw className="w-4 h-4" />Refresh
          </button>
          <span className="flex items-center gap-2 text-sm text-green-600">
            <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></span>Live
          </span>
        </div>
      </div>

      <div className="flex items-center gap-3">
        <FiFilter className="w-4 h-4 text-gray-400" />
        {['all', 'unresolved', 'resolved'].map((f) => (
          <button key={f} onClick={() => setFilter(f)} className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${filter === f ? 'bg-primary-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}>
            {f.charAt(0).toUpperCase() + f.slice(1)}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64"><div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div></div>
      ) : filteredAlerts.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-100">
          <FiAlertTriangle className="w-16 h-16 mx-auto text-gray-200 mb-4" />
          <p className="text-gray-400 text-lg">No alerts found</p>
          <p className="text-gray-300 text-sm mt-1">All systems operating normally</p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredAlerts.map((alert) => (
            <AlertCard key={alert.id} alert={alert} onResolve={handleResolve} onSendAlert={sendEmergencyAlert} isSending={sendingId === alert.id} />
          ))}
        </div>
      )}
    </div>
  );
};

export default AlertsPanel;
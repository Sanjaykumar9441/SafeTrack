import React, { useCallback, useEffect, useState } from 'react';
import { FiAlertTriangle, FiFilter, FiRefreshCw } from 'react-icons/fi';
import { db } from '../../firebase';
import { collection, doc, onSnapshot, orderBy, query, serverTimestamp, updateDoc } from 'firebase/firestore';
import AlertCard from './AlertCard';
import toast from 'react-hot-toast';

const CLOUD_FUNCTION_URL = 'https://sendemergencyalert-zfpscvkqrq-uc.a.run.app';

const AlertsPanel = () => {
  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [sendingId, setSendingId] = useState(null);

  useEffect(() => {
    const q = query(collection(db, 'alerts'), orderBy('timestamp', 'desc'));
    return onSnapshot(q, (snapshot) => {
      setAlerts(snapshot.docs.map((d) => ({ id: d.id, ...d.data() })));
      setLoading(false);
    }, (error) => {
      console.error(error);
      toast.error('Failed to load alerts');
      setLoading(false);
    });
  }, []);

  const sendEmergencyAlert = useCallback(async (alert) => {
    if (sendingId || alert.emergencyAlertSent === true) return;
    setSendingId(alert.id);
    const toastId = toast.loading(`Sending emergency notifications for ${alert.busNumber || 'bus'}…`);
    try {
      const response = await fetch(CLOUD_FUNCTION_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          alertId: alert.id,
          alertType: alert.alertType || 'EMERGENCY',
          busNumber: alert.busNumber || 'Unknown',
          severity: alert.severity || 'CRITICAL',
          latitude: Number(alert.latitude || 0),
          longitude: Number(alert.longitude || 0),
          message: alert.message || 'Emergency detected',
        }),
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok || !data.success) throw new Error(data.error || 'Notification service failed');
      const errors = data.results?.errors || [];
      await updateDoc(doc(db, 'alerts', alert.id), {
        emergencyAlertSent: errors.length === 0,
        emergencyAlertSentAt: serverTimestamp(),
        notificationResult: data.results || null,
        ...(errors.length ? { notificationError: errors.join('; ') } : {}),
      });
      if (errors.length) toast.error(`Partially sent. ${errors.length} notification issue(s).`, { id: toastId });
      else toast.success('Emergency services notified successfully.', { id: toastId });
    } catch (err) {
      toast.error(`Notification failed: ${err.message}`, { id: toastId });
    } finally {
      setSendingId(null);
    }
  }, [sendingId]);

  const handleResolve = async (alertId) => {
    try {
      await updateDoc(doc(db, 'alerts', alertId), { isResolved: true, resolvedBy: 'admin', resolvedAt: serverTimestamp() });
      toast.success('Alert resolved');
    } catch (err) {
      toast.error(`Failed to resolve alert: ${err.message}`);
    }
  };

  const filteredAlerts = filter === 'resolved'
    ? alerts.filter((a) => a.isResolved)
    : filter === 'unresolved'
      ? alerts.filter((a) => !a.isResolved)
      : alerts;

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Emergency Alerts</h1>
          <p className="text-gray-500 mt-1">Real-time alerts. Driver SOS is dispatched once; failed notifications can be retried manually.</p>
        </div>
        <div className="flex items-center gap-3">
          <button onClick={() => window.location.reload()} className="flex items-center gap-2 px-3 py-1.5 bg-gray-100 hover:bg-gray-200 text-gray-600 text-sm rounded-lg">
            <FiRefreshCw className="w-4 h-4" />Refresh
          </button>
          <span className="flex items-center gap-2 text-sm text-green-600"><span className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></span>Live</span>
        </div>
      </div>

      <div className="flex items-center gap-3">
        <FiFilter className="w-4 h-4 text-gray-400" />
        {['all', 'unresolved', 'resolved'].map((f) => (
          <button key={f} onClick={() => setFilter(f)} className={`px-4 py-2 rounded-lg text-sm font-medium ${filter === f ? 'bg-primary-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}>
            {f.charAt(0).toUpperCase() + f.slice(1)}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64"><div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div></div>
      ) : filteredAlerts.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-100"><FiAlertTriangle className="w-16 h-16 mx-auto text-gray-200 mb-4" /><p className="text-gray-400 text-lg">No alerts found</p><p className="text-gray-300 text-sm mt-1">All systems operating normally</p></div>
      ) : (
        <div className="space-y-4">{filteredAlerts.map((alert) => <AlertCard key={alert.id} alert={alert} onResolve={handleResolve} onSendAlert={sendEmergencyAlert} isSending={sendingId === alert.id} />)}</div>
      )}
    </div>
  );
};

export default AlertsPanel;

import React from 'react';
import { FiAlertTriangle, FiCheck, FiMapPin, FiClock, FiPhone } from 'react-icons/fi';

const AlertCard = ({ alert, onResolve, onSendAlert, isSending }) => {
  const severityConfig = {
    CRITICAL: { bg: 'bg-red-50 border-red-200', icon: 'text-red-500', badge: 'bg-red-100 text-red-700' },
    HIGH: { bg: 'bg-orange-50 border-orange-200', icon: 'text-orange-500', badge: 'bg-orange-100 text-orange-700' },
    MEDIUM: { bg: 'bg-yellow-50 border-yellow-200', icon: 'text-yellow-500', badge: 'bg-yellow-100 text-yellow-700' },
    LOW: { bg: 'bg-blue-50 border-blue-200', icon: 'text-blue-500', badge: 'bg-blue-100 text-blue-700' },
  };
  const config = severityConfig[alert.severity] || severityConfig.LOW;
  const formatTimestamp = (ts) => { if (!ts) return 'N/A'; if (ts.toDate) return ts.toDate().toLocaleString(); return new Date(ts).toLocaleString(); };
  const lat = Number(alert.latitude || 0);
  const lng = Number(alert.longitude || 0);
  const hasLocation = lat !== 0 || lng !== 0;
  const notificationSent = alert.emergencyAlertSent === true;

  return (
    <div className={`rounded-xl border p-5 ${config.bg} ${alert.isResolved ? 'opacity-60' : ''}`}>
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-start gap-3 flex-1">
          <FiAlertTriangle className={`w-5 h-5 mt-0.5 flex-shrink-0 ${config.icon} ${!alert.isResolved ? 'animate-pulse' : ''}`} />
          <div className="flex-1">
            <p className="font-medium text-gray-800">{alert.message}</p>
            <div className="flex flex-wrap items-center gap-3 mt-2 text-sm text-gray-500">
              <span>Bus: <strong>{alert.busNumber || 'Unknown'}</strong></span>
              <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${config.badge}`}>{alert.alertType || 'EMERGENCY'}</span>
              <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${config.badge}`}>{alert.severity || 'CRITICAL'}</span>
            </div>
            <div className="flex flex-wrap items-center gap-4 mt-2 text-xs text-gray-400">
              {hasLocation && <a href={`https://maps.google.com/?q=${lat},${lng}`} target="_blank" rel="noreferrer" className="flex items-center gap-1 text-blue-500 hover:underline"><FiMapPin className="w-3 h-3" />{lat.toFixed(4)}, {lng.toFixed(4)}</a>}
              <span className="flex items-center gap-1"><FiClock className="w-3 h-3" />{formatTimestamp(alert.timestamp)}</span>
            </div>
            <div className="flex flex-wrap gap-2 mt-2">
              {notificationSent && <span className="text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full font-medium">Emergency notifications sent</span>}
              {!notificationSent && alert.notificationError && <span className="text-xs bg-red-100 text-red-700 px-2 py-0.5 rounded-full font-medium">Notification failed — retry available</span>}
            </div>
          </div>
        </div>
        <div className="flex flex-col gap-2 flex-shrink-0">
          {!alert.isResolved && <>
            <button onClick={() => onSendAlert(alert)} disabled={isSending || notificationSent} className={`flex items-center gap-1 px-3 py-1.5 text-white text-sm rounded-lg transition-colors ${notificationSent ? 'bg-green-500 cursor-default' : isSending ? 'bg-purple-300 cursor-not-allowed' : 'bg-purple-600 hover:bg-purple-700'}`}>
              <FiPhone className="w-4 h-4" />{notificationSent ? 'Sent' : isSending ? 'Sending...' : 'Alert Services'}
            </button>
            <button onClick={() => onResolve(alert.id)} className="flex items-center gap-1 px-3 py-1.5 bg-green-500 hover:bg-green-600 text-white text-sm rounded-lg transition-colors"><FiCheck className="w-4 h-4" />Resolve</button>
          </>}
          {alert.isResolved && <span className="px-3 py-1.5 bg-green-100 text-green-700 text-sm rounded-lg font-medium text-center">Resolved</span>}
        </div>
      </div>
    </div>
  );
};

export default AlertCard;

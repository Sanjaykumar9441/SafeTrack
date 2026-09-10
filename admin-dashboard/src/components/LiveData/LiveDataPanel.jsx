import React, { useEffect, useState } from 'react';
import { FiActivity, FiThermometer, FiMapPin, FiAlertCircle, FiWifi } from 'react-icons/fi';
import { db } from '../../firebase';
import { collectionGroup, onSnapshot, query, orderBy, limit } from 'firebase/firestore';
import toast from 'react-hot-toast';

const LiveDataPanel = () => {
  const [liveData, setLiveData] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collectionGroup(db, 'readings'), orderBy('timestamp', 'desc'), limit(30));
    return onSnapshot(q, (snapshot) => {
      setLiveData(snapshot.docs.map((d) => ({ id: d.id, ...d.data() })));
      setLoading(false);
    }, (error) => {
      console.error(error);
      toast.error('Failed to load live data');
      setLoading(false);
    });
  }, []);

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div><h1 className="text-2xl font-bold text-gray-800">Live IoT Data</h1><p className="text-gray-500 mt-1">Real-time sensor data from SafeTrack bus devices.</p></div>
        <span className="flex items-center gap-2 text-sm text-green-600"><span className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></span>Live streaming</span>
      </div>
      {loading ? (
        <div className="flex items-center justify-center h-64"><div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div></div>
      ) : liveData.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-100"><FiWifi className="w-16 h-16 mx-auto text-gray-200 mb-4" /><p className="text-gray-400 text-lg">No live data available</p><p className="text-gray-300 text-sm mt-1">Start the SafeTrack simulator or connect the IoT device.</p></div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {liveData.map((data) => {
            const emergency = Boolean(data.isEmergency || data.flameDetected || data.smokeDetected || Number(data.tiltAngle || 0) > 30);
            return (
              <div key={`${data.deviceId || 'device'}-${data.id}`} className={`bg-white rounded-xl shadow-sm border p-5 card-hover ${emergency ? 'border-red-300 bg-red-50' : 'border-gray-100'}`}>
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3"><div className={`w-10 h-10 rounded-lg flex items-center justify-center ${emergency ? 'bg-red-100' : 'bg-primary-100'}`}><FiActivity className={`w-5 h-5 ${emergency ? 'text-red-600' : 'text-primary-600'}`} /></div><div><h3 className="font-semibold text-gray-800">{data.busNumber || data.busId || 'Unknown bus'}</h3><p className="text-xs text-gray-400">Device: {data.deviceId || 'N/A'}</p></div></div>
                  {emergency && <span className="flex items-center gap-1 bg-red-100 text-red-700 px-2 py-1 rounded-full text-xs font-bold animate-pulse"><FiAlertCircle className="w-3 h-3" />EMERGENCY</span>}
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div className="bg-gray-50 rounded-lg p-3"><div className="flex items-center gap-2 text-xs text-gray-500 mb-1"><FiMapPin className="w-3 h-3" />Location</div><p className="text-sm font-medium text-gray-700">{Number(data.latitude || 0).toFixed(4)}, {Number(data.longitude || 0).toFixed(4)}</p></div>
                  <div className="bg-gray-50 rounded-lg p-3"><div className="flex items-center gap-2 text-xs text-gray-500 mb-1"><FiThermometer className="w-3 h-3" />Temperature</div><p className={`text-sm font-medium ${Number(data.temperature || 0) > 50 ? 'text-red-600' : 'text-gray-700'}`}>{Number(data.temperature || 0).toFixed(1)}°C</p></div>
                  <div className="bg-gray-50 rounded-lg p-3"><div className="text-xs text-gray-500 mb-1">Speed</div><p className="text-sm font-medium text-gray-700">{Number(data.speed || 0).toFixed(1)} km/h</p></div>
                  <div className="bg-gray-50 rounded-lg p-3"><div className="text-xs text-gray-500 mb-1">Tilt</div><p className={`text-sm font-medium ${Number(data.tiltAngle || 0) > 30 ? 'text-red-600' : 'text-gray-700'}`}>{Number(data.tiltAngle || 0).toFixed(1)}°</p></div>
                </div>
                <div className="flex flex-wrap gap-2 mt-3"><Badge label="Flame" value={data.flameDetected} /><Badge label="Smoke" value={data.smokeDetected} />{data.seatCount !== undefined && <span className="px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-700">Seats: {data.seatCount}</span>}</div>
                <p className="text-xs text-gray-400 mt-3">Last updated: {data.timestamp?.toDate ? data.timestamp.toDate().toLocaleString() : 'N/A'}</p>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

const Badge = ({ label, value }) => <span className={`px-2 py-1 rounded-full text-xs font-medium ${value ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700'}`}>{label}: {value ? 'YES' : 'No'}</span>;

export default LiveDataPanel;

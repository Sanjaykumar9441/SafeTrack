import React, { useState, useEffect } from 'react';
import { FiActivity, FiAlertTriangle, FiMapPin } from 'react-icons/fi';
import { FaBus } from 'react-icons/fa';
import { db } from '../../firebase';
import { collection, onSnapshot, query, orderBy, limit, where } from 'firebase/firestore';
import StatsCard from './StatsCard';
import toast from 'react-hot-toast';

const DashboardHome = () => {
  const [stats, setStats] = useState({
    totalBuses: 0,
    activeBuses: 0,
    totalRoutes: 0,
    unresolvedAlerts: 0,
  });
  const [recentAlerts, setRecentAlerts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubBuses = onSnapshot(collection(db, 'buses'), (snapshot) => {
      const totalBuses = snapshot.size;
      const activeBuses = snapshot.docs.filter(doc => doc.data().isActive).length;
      setStats(prev => ({ ...prev, totalBuses, activeBuses }));
      setLoading(false);
    }, () => {
      toast.error('Failed to load bus data');
      setLoading(false);
    });

    const unsubRoutes = onSnapshot(collection(db, 'routes'), (snapshot) => {
      setStats(prev => ({ ...prev, totalRoutes: snapshot.size }));
    });

    const alertsQuery = query(
      collection(db, 'alerts'),
      where('isResolved', '==', false)
    );
    const unsubUnresolved = onSnapshot(alertsQuery, (snapshot) => {
      setStats(prev => ({ ...prev, unresolvedAlerts: snapshot.size }));
    });

    const recentQuery = query(
      collection(db, 'alerts'),
      orderBy('timestamp', 'desc'),
      limit(5)
    );
    const unsubRecent = onSnapshot(recentQuery, (snapshot) => {
      const alerts = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));
      setRecentAlerts(alerts);
    });

    return () => {
      unsubBuses();
      unsubRoutes();
      unsubUnresolved();
      unsubRecent();
    };
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-2xl p-8 shadow-sm border border-gray-100">
        <h1 className="text-4xl font-bold gradient-text mb-2">
          SafeTrack Admin Panel
        </h1>
        <p className="text-gray-500 text-lg">
          Smart Bus Tracking & Safety System — Real-time monitoring dashboard
        </p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatsCard
          icon={FaBus}
          title="Total Buses"
          value={stats.totalBuses}
          subtitle="Registered in system"
          color="blue"
        />
        <StatsCard
          icon={FiActivity}
          title="Active Buses"
          value={stats.activeBuses}
          subtitle="Currently tracked"
          color="green"
        />
        <StatsCard
          icon={FiMapPin}
          title="Total Routes"
          value={stats.totalRoutes}
          subtitle="Configured routes"
          color="purple"
        />
        <StatsCard
          icon={FiAlertTriangle}
          title="Active Alerts"
          value={stats.unresolvedAlerts}
          subtitle="Needs attention"
          color="red"
        />
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-100">
        <div className="flex items-center justify-between p-6 border-b border-gray-100">
          <h2 className="text-lg font-semibold text-gray-800">Recent Alerts</h2>
          <span className="flex items-center gap-2 text-sm text-green-600">
            <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></span>
            Live
          </span>
        </div>

        <div className="divide-y divide-gray-50">
          {recentAlerts.length === 0 ? (
            <div className="p-8 text-center text-gray-400">
              <FiAlertTriangle className="w-12 h-12 mx-auto mb-3 opacity-30" />
              <p>No recent alerts. All systems are safe!</p>
            </div>
          ) : (
            recentAlerts.map((alert) => (
              <div key={alert.id} className="px-6 py-4 flex items-center justify-between hover:bg-gray-50 transition-colors">
                <div className="flex items-center gap-4">
                  <div className={`w-3 h-3 rounded-full ${alert.severity === 'CRITICAL' ? 'bg-red-500 animate-pulse' :
                    alert.severity === 'HIGH' ? 'bg-orange-500' :
                      alert.severity === 'MEDIUM' ? 'bg-yellow-500' : 'bg-blue-500'
                    }`}></div>
                  <div>
                    <p className="text-sm font-medium text-gray-700">{alert.message}</p>
                    <p className="text-xs text-gray-400">Bus: {alert.busNumber} • {alert.alertType}</p>
                  </div>
                </div>
                <div className="text-right">
                  <span className={`inline-block px-2 py-1 rounded-full text-xs font-medium ${alert.severity === 'CRITICAL' ? 'bg-red-100 text-red-700' :
                    alert.severity === 'HIGH' ? 'bg-orange-100 text-orange-700' :
                      alert.severity === 'MEDIUM' ? 'bg-yellow-100 text-yellow-700' : 'bg-blue-100 text-blue-700'
                    }`}>
                    {alert.severity}
                  </span>
                  <p className="text-xs text-gray-400 mt-1">
                    {alert.timestamp?.toDate ? new Date(alert.timestamp.toDate()).toLocaleString() : 'N/A'}
                  </p>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};

export default DashboardHome;
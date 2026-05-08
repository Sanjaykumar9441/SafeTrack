import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { FiPlus, FiMapPin, FiClock, FiTrash2, FiEdit2 } from 'react-icons/fi';
import { db } from '../../firebase';
import { collection, onSnapshot, doc, deleteDoc } from 'firebase/firestore';
import toast from 'react-hot-toast';

const RouteList = () => {
  const navigate = useNavigate();
  const [routes, setRoutes] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onSnapshot(collection(db, 'routes'), (snapshot) => {
      setRoutes(snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
      setLoading(false);
    }, () => { toast.error('Failed to load routes'); setLoading(false); });
    return () => unsubscribe();
  }, []);

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this route?')) return;
    try {
      await deleteDoc(doc(db, 'routes', id));
      toast.success('Route deleted');
    } catch (e) { toast.error('Failed to delete route'); }
  };

  const handleEdit = (route) => {
    navigate('/dashboard/routes/create', { state: { editRoute: route } });
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Route Management</h1>
          <p className="text-gray-500 mt-1">{routes.length} routes configured</p>
        </div>
        <div className="flex gap-3">
          <span className="flex items-center gap-2 text-sm text-green-600 px-3">
            <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></span>Live
          </span>
          <button onClick={() => navigate('/dashboard/routes/create')} className="flex items-center gap-2 bg-primary-600 hover:bg-primary-700 text-white px-4 py-2 rounded-lg transition-colors">
            <FiPlus className="w-5 h-5" /><span>Add Route</span>
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64"><div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div></div>
      ) : routes.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-100">
          <p className="text-gray-400 text-lg">No routes configured</p>
          <button onClick={() => navigate('/dashboard/routes/create')} className="mt-4 text-primary-600 hover:text-primary-700 font-medium">Create your first route →</button>
        </div>
      ) : (
        <div className="space-y-4">
          {routes.map((route) => (
            <div key={route.id} className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 card-hover">
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-3">
                    <span className="bg-primary-100 text-primary-700 px-3 py-1 rounded-full text-sm font-medium">{route.serviceNumber}</span>
                    <span className="text-sm text-gray-500">Bus: {route.busNumber} - {route.busName}</span>
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${route.isActive ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'}`}>{route.isActive ? 'Active' : 'Inactive'}</span>
                  </div>
                  <div className="flex items-center gap-2 mb-3">
                    <div className="flex items-center gap-1"><FiMapPin className="w-4 h-4 text-green-500" /><span className="font-medium text-gray-700">{route.source}</span></div>
                    <span className="text-gray-400">→</span>
                    {route.intermediateStops?.length > 0 && (<><span className="text-sm text-gray-400">({route.intermediateStops.length} stops)</span><span className="text-gray-400">→</span></>)}
                    <div className="flex items-center gap-1"><FiMapPin className="w-4 h-4 text-red-500" /><span className="font-medium text-gray-700">{route.destination}</span></div>
                  </div>
                  <div className="flex items-center gap-4 text-sm text-gray-500">
                    {route.departureTime && (<div className="flex items-center gap-1"><FiClock className="w-4 h-4" /><span>Departs: {route.departureTime}</span></div>)}
                    {route.arrivalTime && (<div className="flex items-center gap-1"><FiClock className="w-4 h-4" /><span>Arrives: {route.arrivalTime}</span></div>)}
                  </div>
                  {route.intermediateStops?.length > 0 && (
                    <div className="mt-3 flex flex-wrap gap-2">
                      {route.intermediateStops.map((stop, i) => (
                        <span key={i} className="text-xs bg-gray-100 text-gray-600 px-2 py-1 rounded-md">{stop.name} {stop.arrivalTime && `(${stop.arrivalTime})`}</span>
                      ))}
                    </div>
                  )}
                </div>
                <div className="flex items-center gap-2 ml-4">
                  <button onClick={() => handleEdit(route)} className="p-2 rounded-lg hover:bg-blue-50 text-blue-600 transition-colors" title="Edit route"><FiEdit2 className="w-5 h-5" /></button>
                  <button onClick={() => handleDelete(route.id)} className="p-2 rounded-lg hover:bg-red-50 text-red-600 transition-colors" title="Delete route"><FiTrash2 className="w-5 h-5" /></button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default RouteList;
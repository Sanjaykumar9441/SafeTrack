import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { FiMapPin, FiClock, FiPlus, FiX } from 'react-icons/fi';
import { db } from '../../firebase';
import { collection, addDoc, getDocs, doc, updateDoc, serverTimestamp } from 'firebase/firestore';
import toast from 'react-hot-toast';

const CreateRoute = () => {
  const navigate = useNavigate();
  const location = useLocation();

  // Check if editing
  const editRoute = location.state?.editRoute || null;
  const isEditing = !!editRoute;

  const [buses, setBuses] = useState([]);
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    busId: '',
    source: '',
    destination: '',
    departureTime: '',
    arrivalTime: '',
    serviceNumber: '',
  });
  const [stops, setStops] = useState([]);
  const [errors, setErrors] = useState({});

  // Fetch buses for dropdown
  useEffect(() => {
    const fetchBuses = async () => {
      try {
        const snapshot = await getDocs(collection(db, 'buses'));
        setBuses(snapshot.docs.map(d => ({ id: d.id, ...d.data() })));
      } catch {
        toast.error('Failed to load buses');
      }
    };
    fetchBuses();
  }, []);

  // Pre-fill form if editing
  useEffect(() => {
    if (editRoute) {
      setFormData({
        busId: editRoute.busId || '',
        source: editRoute.source || '',
        destination: editRoute.destination || '',
        departureTime: editRoute.departureTime || '',
        arrivalTime: editRoute.arrivalTime || '',
        serviceNumber: editRoute.serviceNumber || '',
      });
      setStops(
        (editRoute.intermediateStops || []).map((s, i) => ({
          name: s.name || '',
          arrivalTime: s.arrivalTime || '',
          orderIndex: i + 1,
          latitude: String(s.latitude || ''),
          longitude: String(s.longitude || ''),
        }))
      );
    }
  }, [editRoute]);

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
    if (errors[e.target.name]) setErrors({ ...errors, [e.target.name]: '' });
  };

  const addStop = () => {
    setStops([...stops, { name: '', arrivalTime: '', orderIndex: stops.length + 1, latitude: '', longitude: '' }]);
  };

  const removeStop = (index) => setStops(stops.filter((_, i) => i !== index));

  const updateStop = (index, field, value) => {
    const updated = [...stops];
    updated[index][field] = value;
    setStops(updated);
  };

  const validate = () => {
    const newErrors = {};
    if (!formData.busId) newErrors.busId = 'Please select a bus';
    if (!formData.source.trim()) newErrors.source = 'Source is required';
    if (!formData.destination.trim()) newErrors.destination = 'Destination is required';
    if (!formData.serviceNumber.trim()) newErrors.serviceNumber = 'Service number is required';
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;

    setLoading(true);
    try {
      const selectedBus = buses.find(b => b.id === formData.busId);
      const payload = {
        busId: formData.busId,
        busNumber: selectedBus?.busNumber || '',
        busName: selectedBus?.busName || '',
        source: formData.source.trim(),
        destination: formData.destination.trim(),
        departureTime: formData.departureTime.trim(),
        arrivalTime: formData.arrivalTime.trim(),
        serviceNumber: formData.serviceNumber.trim(),
        intermediateStops: stops.map((s, i) => ({
          name: s.name,
          arrivalTime: s.arrivalTime,
          orderIndex: i + 1,
          latitude: parseFloat(s.latitude) || 0,
          longitude: parseFloat(s.longitude) || 0,
        })),
        isActive: true,
      };

      if (isEditing) {
        await updateDoc(doc(db, 'routes', editRoute.id), {
          ...payload,
          updatedAt: serverTimestamp(),
        });
        toast.success('Route updated successfully!');
      } else {
        await addDoc(collection(db, 'routes'), {
          ...payload,
          createdAt: serverTimestamp(),
        });
        toast.success('Route created successfully!');
      }
      navigate('/dashboard/routes');
    } catch (error) {
      toast.error(`Failed to ${isEditing ? 'update' : 'create'} route: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-3xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-800">
          {isEditing ? 'Edit Route' : 'Create Route'}
        </h1>
        <p className="text-gray-500 mt-1">
          {isEditing
            ? `Editing route ${editRoute.serviceNumber}`
            : 'Define a route and assign it to a bus'}
        </p>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-8">
        <form onSubmit={handleSubmit} className="space-y-6">

          {/* Select Bus */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Select Bus *
            </label>
            <select
              name="busId"
              value={formData.busId}
              onChange={handleChange}
              className={`w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none ${errors.busId ? 'border-red-500 bg-red-50' : 'border-gray-300'
                }`}
            >
              <option value="">-- Select a bus --</option>
              {buses.map((bus) => (
                <option key={bus.id} value={bus.id}>
                  {bus.busNumber} - {bus.busName}
                </option>
              ))}
            </select>
            {errors.busId && <p className="text-red-500 text-xs mt-1">{errors.busId}</p>}
          </div>

          {/* Service Number */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Service/Route Number *
            </label>
            <input
              type="text"
              name="serviceNumber"
              value={formData.serviceNumber}
              onChange={handleChange}
              placeholder="e.g., R-101"
              className={`w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none ${errors.serviceNumber ? 'border-red-500 bg-red-50' : 'border-gray-300'
                }`}
            />
            {errors.serviceNumber && <p className="text-red-500 text-xs mt-1">{errors.serviceNumber}</p>}
          </div>

          {/* Source and Destination */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Starting Point *
              </label>
              <div className="relative">
                <FiMapPin className="absolute left-3 top-1/2 -translate-y-1/2 text-green-500 w-5 h-5" />
                <input
                  type="text"
                  name="source"
                  value={formData.source}
                  onChange={handleChange}
                  placeholder="e.g., Central Station"
                  className={`w-full pl-10 pr-4 py-3 border rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none ${errors.source ? 'border-red-500 bg-red-50' : 'border-gray-300'
                    }`}
                />
              </div>
              {errors.source && <p className="text-red-500 text-xs mt-1">{errors.source}</p>}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Destination *
              </label>
              <div className="relative">
                <FiMapPin className="absolute left-3 top-1/2 -translate-y-1/2 text-red-500 w-5 h-5" />
                <input
                  type="text"
                  name="destination"
                  value={formData.destination}
                  onChange={handleChange}
                  placeholder="e.g., Airport"
                  className={`w-full pl-10 pr-4 py-3 border rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none ${errors.destination ? 'border-red-500 bg-red-50' : 'border-gray-300'
                    }`}
                />
              </div>
              {errors.destination && <p className="text-red-500 text-xs mt-1">{errors.destination}</p>}
            </div>
          </div>

          {/* Timing */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Departure Time
              </label>
              <div className="relative">
                <FiClock className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
                <input
                  type="text"
                  name="departureTime"
                  value={formData.departureTime}
                  onChange={handleChange}
                  placeholder="e.g., 08:00 AM"
                  className="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Arrival Time
              </label>
              <div className="relative">
                <FiClock className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
                <input
                  type="text"
                  name="arrivalTime"
                  value={formData.arrivalTime}
                  onChange={handleChange}
                  placeholder="e.g., 10:30 AM"
                  className="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
                />
              </div>
            </div>
          </div>

          {/* Intermediate Stops — UPDATED with lat/lng */}
          <div>
            <div className="flex items-center justify-between mb-3">
              <div>
                <label className="text-sm font-medium text-gray-700">
                  Intermediate Stops
                </label>
                <p className="text-xs text-gray-400 mt-0.5">
                  Add GPS coordinates so passengers can find nearby stops
                </p>
              </div>
              <button
                type="button"
                onClick={addStop}
                className="flex items-center gap-1 text-primary-600 hover:text-primary-700 text-sm font-medium"
              >
                <FiPlus className="w-4 h-4" />
                Add Stop
              </button>
            </div>

            {stops.length === 0 ? (
              <p className="text-gray-400 text-sm italic">No intermediate stops added</p>
            ) : (
              <div className="space-y-4">
                {stops.map((stop, index) => (
                  <div key={index} className="p-4 bg-gray-50 rounded-lg border border-gray-100">
                    {/* Row 1: index + name + time + delete */}
                    <div className="flex items-center gap-3 mb-3">
                      <span className="text-xs font-bold text-primary-600 bg-primary-100 w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0">
                        {index + 1}
                      </span>
                      <input
                        type="text"
                        value={stop.name}
                        onChange={(e) => updateStop(index, 'name', e.target.value)}
                        placeholder="Stop name"
                        className="flex-1 px-3 py-2 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 outline-none"
                      />
                      <input
                        type="text"
                        value={stop.arrivalTime}
                        onChange={(e) => updateStop(index, 'arrivalTime', e.target.value)}
                        placeholder="Time (e.g. 08:30 AM)"
                        className="w-36 px-3 py-2 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 outline-none"
                      />
                      <button
                        type="button"
                        onClick={() => removeStop(index)}
                        className="p-1 rounded hover:bg-red-100 text-red-500 transition-colors"
                      >
                        <FiX className="w-4 h-4" />
                      </button>
                    </div>

                    {/* Row 2: lat + lng (NEW) */}
                    <div className="flex items-center gap-3 ml-9">
                      <FiMapPin className="w-4 h-4 text-gray-400 flex-shrink-0" />
                      <input
                        type="number"
                        step="any"
                        value={stop.latitude}
                        onChange={(e) => updateStop(index, 'latitude', e.target.value)}
                        placeholder="Latitude (e.g. 17.5937)"
                        className="flex-1 px-3 py-2 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 outline-none"
                      />
                      <input
                        type="number"
                        step="any"
                        value={stop.longitude}
                        onChange={(e) => updateStop(index, 'longitude', e.target.value)}
                        placeholder="Longitude (e.g. 82.2600)"
                        className="flex-1 px-3 py-2 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-primary-500 outline-none"
                      />
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Actions */}
          <div className="flex gap-4 pt-4">
            <button
              type="submit"
              disabled={loading}
              className="flex-1 bg-primary-600 hover:bg-primary-700 text-white font-semibold py-3 rounded-lg transition-all disabled:opacity-50 flex items-center justify-center"
            >
              {loading ? (
                <>
                  <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2"></div>
                  {isEditing ? 'Updating...' : 'Creating...'}
                </>
              ) : (
                isEditing ? 'Update Route' : 'Create Route'
              )}
            </button>
            <button
              type="button"
              onClick={() => navigate('/dashboard/routes')}
              className="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-all"
            >
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default CreateRoute;
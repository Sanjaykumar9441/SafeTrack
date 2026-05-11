import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { FiHash, FiUsers, FiWifi, FiPhone } from 'react-icons/fi';
import { FaBus } from 'react-icons/fa';
import { db } from '../../firebase';
import { collection, addDoc, doc, updateDoc, serverTimestamp } from 'firebase/firestore';
import toast from 'react-hot-toast';

const CreateBus = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const editBus = location.state?.editBus || null;
  const isEditing = !!editBus;

  const [formData, setFormData] = useState({
    busNumber: '', busName: '', seatCapacity: '',
    deviceId: '', helpline: '', isActive: false,
  });
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (editBus) {
      setFormData({
        busNumber: editBus.busNumber || '', busName: editBus.busName || '',
        seatCapacity: String(editBus.seatCapacity || ''), deviceId: editBus.deviceId || '',
        helpline: editBus.helpline || '', isActive: editBus.isActive || false,
      });
    }
  }, [editBus]);

  const validate = () => {
    const newErrors = {};
    if (!formData.busNumber.trim()) newErrors.busNumber = 'Bus number is required';
    if (!formData.busName.trim()) newErrors.busName = 'Bus name is required';
    if (!formData.seatCapacity || parseInt(formData.seatCapacity) < 1) newErrors.seatCapacity = 'Seat capacity must be at least 1';
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleChange = (e) => {
    const value = e.target.type === 'checkbox' ? e.target.checked : e.target.value;
    setFormData({ ...formData, [e.target.name]: value });
    if (errors[e.target.name]) setErrors({ ...errors, [e.target.name]: '' });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;
    setLoading(true);
    try {
      const payload = {
        busNumber: formData.busNumber.trim().toUpperCase(),
        busName: formData.busName.trim(),
        seatCapacity: parseInt(formData.seatCapacity),
        deviceId: formData.deviceId.trim(),
        helpline: formData.helpline.trim(),
        isActive: formData.isActive,
        updatedAt: serverTimestamp(),
      };
      if (isEditing) {
        await updateDoc(doc(db, 'buses', editBus.id), payload);
        toast.success('Bus updated successfully!');
      } else {
        await addDoc(collection(db, 'buses'), {
          ...payload,
          availableSeats: parseInt(formData.seatCapacity),
          status: 'STOPPED', safetyStatus: 'SAFE',
          currentLatitude: 0, currentLongitude: 0, temperature: 0,
          createdAt: serverTimestamp(),
        });
        toast.success('Bus created successfully!');
      }
      navigate('/dashboard/buses');
    } catch (error) {
      toast.error(`Failed to ${isEditing ? 'update' : 'create'} bus: ${error.message}`);
    } finally { setLoading(false); }
  };

  const inputClass = (field) => `w-full pl-10 pr-4 py-3 border rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none ${errors[field] ? 'border-red-500 bg-red-50' : 'border-gray-300'}`;

  return (
    <div className="max-w-2xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-800">{isEditing ? 'Edit Bus' : 'Create New Bus'}</h1>
        <p className="text-gray-500 mt-1">{isEditing ? `Editing ${editBus.busNumber}` : 'Add a new bus to the SafeTrack system'}</p>
      </div>
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-8">
        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Bus Number *</label>
            <div className="relative">
              <FiHash className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input type="text" name="busNumber" value={formData.busNumber} onChange={handleChange} placeholder="e.g., KA-01-AB-1234" className={inputClass('busNumber')} />
            </div>
            {errors.busNumber && <p className="text-red-500 text-xs mt-1">{errors.busNumber}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Bus Name *</label>
            <div className="relative">
              <FaBus className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input type="text" name="busName" value={formData.busName} onChange={handleChange} placeholder="e.g., City Express" className={inputClass('busName')} />
            </div>
            {errors.busName && <p className="text-red-500 text-xs mt-1">{errors.busName}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Seat Capacity *</label>
            <div className="relative">
              <FiUsers className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input type="number" name="seatCapacity" value={formData.seatCapacity} onChange={handleChange} placeholder="e.g., 40" min="1" className={inputClass('seatCapacity')} />
            </div>
            {errors.seatCapacity && <p className="text-red-500 text-xs mt-1">{errors.seatCapacity}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">ESP32 Device ID <span className="ml-2 text-xs text-gray-400 font-normal">(required for live map in mobile app)</span></label>
            <div className="relative">
              <FiWifi className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input type="text" name="deviceId" value={formData.deviceId} onChange={handleChange} placeholder="e.g., ESP32_001" className="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none" />
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Helpline Number <span className="ml-2 text-xs text-gray-400 font-normal">(shown to passengers in mobile app)</span></label>
            <div className="relative">
              <FiPhone className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input type="text" name="helpline" value={formData.helpline} onChange={handleChange} placeholder="e.g., 1800-XXX-XXXX" className="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none" />
            </div>
          </div>
          <div className="flex items-center gap-3 p-4 bg-gray-50 rounded-lg">
            <input type="checkbox" id="isActive" name="isActive" checked={formData.isActive} onChange={handleChange} className="w-4 h-4 text-primary-600 rounded" />
            <label htmlFor="isActive" className="text-sm font-medium text-gray-700 cursor-pointer">{isEditing ? 'Bus is active' : 'Activate bus immediately'}</label>
            <span className="text-xs text-gray-400">(inactive buses are hidden from passenger app)</span>
          </div>
          <div className="flex gap-4 pt-4">
            <button type="submit" disabled={loading} className="flex-1 bg-primary-600 hover:bg-primary-700 text-white font-semibold py-3 rounded-lg transition-all disabled:opacity-50 flex items-center justify-center">
              {loading ? (<><div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2"></div>{isEditing ? 'Updating...' : 'Creating...'}</>) : (isEditing ? 'Update Bus' : 'Create Bus')}
            </button>
            <button type="button" onClick={() => navigate('/dashboard/buses')} className="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-all">Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default CreateBus;
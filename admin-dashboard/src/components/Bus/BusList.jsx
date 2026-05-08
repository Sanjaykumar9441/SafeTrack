import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { FiPlus, FiSearch } from 'react-icons/fi';
import { db } from '../../firebase';
import { collection, onSnapshot, doc, deleteDoc } from 'firebase/firestore';
import BusCard from './BusCard';
import toast from 'react-hot-toast';

const BusList = () => {
  const navigate = useNavigate();
  const [buses, setBuses] = useState([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onSnapshot(collection(db, 'buses'), (snapshot) => {
      setBuses(snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
      setLoading(false);
    }, () => { toast.error('Failed to load buses'); setLoading(false); });
    return () => unsubscribe();
  }, []);

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this bus?')) return;
    try {
      await deleteDoc(doc(db, 'buses', id));
      toast.success('Bus deleted');
    } catch (e) { toast.error('Failed to delete bus'); }
  };

  const handleEdit = (bus) => navigate('/dashboard/buses/create', { state: { editBus: bus } });

  const filtered = buses.filter(b =>
    (b.busNumber || '').toLowerCase().includes(search.toLowerCase()) ||
    (b.busName || '').toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Bus Management</h1>
          <p className="text-gray-500 mt-1">{buses.length} buses registered</p>
        </div>
        <div className="flex gap-3">
          <span className="flex items-center gap-2 text-sm text-green-600 px-3">
            <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></span>Live
          </span>
          <button onClick={() => navigate('/dashboard/buses/create')} className="flex items-center gap-2 bg-primary-600 hover:bg-primary-700 text-white px-4 py-2 rounded-lg transition-colors">
            <FiPlus className="w-5 h-5" /><span>Add Bus</span>
          </button>
        </div>
      </div>

      <div className="relative max-w-md">
        <FiSearch className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
        <input type="text" value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search by bus number or name..." className="w-full pl-10 pr-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none" />
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-100">
          <p className="text-gray-400 text-lg">No buses found</p>
          <button onClick={() => navigate('/dashboard/buses/create')} className="mt-4 text-primary-600 hover:text-primary-700 font-medium">Create your first bus →</button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {filtered.map(bus => <BusCard key={bus.id} bus={bus} onEdit={handleEdit} onDelete={handleDelete} />)}
        </div>
      )}
    </div>
  );
};

export default BusList;
import React from 'react';
import { FiMapPin, FiUsers, FiThermometer, FiEdit2, FiTrash2 } from 'react-icons/fi';
import { FaBus } from 'react-icons/fa';

const BusCard = ({ bus, onEdit, onDelete }) => {
  const statusColors = {
    RUNNING: 'bg-green-100 text-green-700',
    STOPPED: 'bg-gray-100 text-gray-700',
    MAINTENANCE: 'bg-yellow-100 text-yellow-700',
  };

  const safetyColors = {
    SAFE: 'bg-green-100 text-green-700',
    WARNING: 'bg-yellow-100 text-yellow-700',
    DANGER: 'bg-red-100 text-red-700',
  };

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5 card-hover">
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-primary-100 rounded-lg flex items-center justify-center">
            <FaBus className="w-5 h-5 text-primary-600" />
          </div>
          <div>
            <h3 className="font-semibold text-gray-800">{bus.busNumber}</h3>
            <p className="text-sm text-gray-500">{bus.busName}</p>
          </div>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => onEdit(bus)}
            className="p-2 rounded-lg hover:bg-blue-50 text-blue-600 transition-colors"
            title="Edit"
          >
            <FiEdit2 className="w-4 h-4" />
          </button>
          <button
            onClick={() => onDelete(bus.id)}
            className="p-2 rounded-lg hover:bg-red-50 text-red-600 transition-colors"
            title="Delete"
          >
            <FiTrash2 className="w-4 h-4" />
          </button>
        </div>
      </div>

      <div className="space-y-2">
        <div className="flex items-center gap-2 text-sm text-gray-500">
          <FiUsers className="w-4 h-4" />
          <span>Seats: {bus.availableSeats}/{bus.seatCapacity}</span>
        </div>
        {bus.temperature > 0 && (
          <div className="flex items-center gap-2 text-sm text-gray-500">
            <FiThermometer className="w-4 h-4" />
            <span>Temp: {bus.temperature}°C</span>
          </div>
        )}
        {(bus.currentLatitude !== 0 || bus.currentLongitude !== 0) && (
          <div className="flex items-center gap-2 text-sm text-gray-500">
            <FiMapPin className="w-4 h-4" />
            <span>
              {bus.currentLatitude.toFixed(4)}, {bus.currentLongitude.toFixed(4)}
            </span>
          </div>
        )}
      </div>

      <div className="flex gap-2 mt-4">
        <span className={`px-2 py-1 rounded-full text-xs font-medium ${statusColors[bus.status] || statusColors.STOPPED}`}>
          {bus.status}
        </span>
        <span className={`px-2 py-1 rounded-full text-xs font-medium ${safetyColors[bus.safetyStatus] || safetyColors.SAFE}`}>
          {bus.safetyStatus}
        </span>
        {bus.isActive && (
          <span className="px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-700">
            Active
          </span>
        )}
      </div>
    </div>
  );
};

export default BusCard;
import React from 'react';
import { NavLink } from 'react-router-dom';
import {
  FiHome, FiMapPin, FiAlertTriangle,
  FiActivity, FiLogOut, FiPlus
} from 'react-icons/fi';
import { FaBus } from 'react-icons/fa';
import { useAuth } from '../../hooks/useAuth';

const Sidebar = ({ isOpen, onClose }) => {
  const { logout } = useAuth();

  const navItems = [
    { to: '/dashboard', icon: FiHome, label: 'Dashboard', end: true },
    { to: '/dashboard/buses', icon: FaBus, label: 'Bus List' },
    { to: '/dashboard/buses/create', icon: FiPlus, label: 'Create Bus' },
    { to: '/dashboard/routes', icon: FiMapPin, label: 'Routes' },
    { to: '/dashboard/routes/create', icon: FiPlus, label: 'Create Route' },
    { to: '/dashboard/alerts', icon: FiAlertTriangle, label: 'Alerts' },
    { to: '/dashboard/live-data', icon: FiActivity, label: 'Live Data' },
  ];

  const linkClasses = ({ isActive }) =>
    `flex items-center gap-3 px-4 py-3 rounded-lg transition-all duration-200 ${isActive
      ? 'bg-primary-600 text-white shadow-md'
      : 'text-gray-300 hover:bg-primary-800 hover:text-white'
    }`;

  return (
    <>
      {isOpen && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 z-40 lg:hidden"
          onClick={onClose}
        />
      )}

      <aside
        className={`fixed top-0 left-0 z-50 h-full w-64 bg-primary-900 transform transition-transform duration-300 lg:translate-x-0 lg:static lg:z-auto ${isOpen ? 'translate-x-0' : '-translate-x-full'
          }`}
      >
        <div className="flex items-center gap-3 px-6 py-6 border-b border-primary-800">
          <div className="w-10 h-10 bg-primary-600 rounded-xl flex items-center justify-center">
            <FaBus className="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 className="text-white font-bold text-lg">SafeTrack</h1>
            <p className="text-primary-400 text-xs">Admin Panel</p>
          </div>
        </div>

        <nav className="px-4 py-6 space-y-1 flex-1 overflow-y-auto">
          <p className="text-primary-500 text-xs font-semibold uppercase tracking-wider px-4 mb-3">
            Main Menu
          </p>
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={linkClasses}
              onClick={onClose}
            >
              <item.icon className="w-5 h-5 flex-shrink-0" />
              <span className="text-sm font-medium">{item.label}</span>
            </NavLink>
          ))}
        </nav>

        <div className="px-4 pb-6">
          <button
            onClick={logout}
            className="flex items-center gap-3 px-4 py-3 rounded-lg text-gray-300 hover:bg-red-600 hover:text-white transition-all duration-200 w-full"
          >
            <FiLogOut className="w-5 h-5" />
            <span className="text-sm font-medium">Logout</span>
          </button>
        </div>
      </aside>
    </>
  );
};

export default Sidebar;
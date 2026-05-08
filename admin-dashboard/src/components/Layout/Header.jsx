import React from 'react';
import { FiMenu, FiBell, FiUser } from 'react-icons/fi';
import { useAuth } from '../../hooks/useAuth';

const Header = ({ onMenuClick }) => {
  const { admin } = useAuth();

  return (
    <header className="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between sticky top-0 z-30">
      <button
        onClick={onMenuClick}
        className="lg:hidden p-2 rounded-lg hover:bg-gray-100 transition-colors"
      >
        <FiMenu className="w-6 h-6 text-gray-600" />
      </button>

      <div className="hidden lg:block">
        <h2 className="text-lg font-semibold text-gray-800">Welcome back!</h2>
        <p className="text-sm text-gray-500">SafeTrack Admin Dashboard</p>
      </div>

      <div className="flex items-center gap-4">
        <button className="relative p-2 rounded-lg hover:bg-gray-100 transition-colors">
          <FiBell className="w-5 h-5 text-gray-600" />
          <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full"></span>
        </button>

        <div className="flex items-center gap-3">
          <div className="w-9 h-9 bg-primary-100 rounded-full flex items-center justify-center">
            <FiUser className="w-5 h-5 text-primary-600" />
          </div>
          <div className="hidden sm:block">
            <p className="text-sm font-medium text-gray-700">{admin?.displayName || 'Admin'}</p>
            <p className="text-xs text-gray-400">{admin?.email}</p>
          </div>
        </div>
      </div>
    </header>
  );
};

export default Header;
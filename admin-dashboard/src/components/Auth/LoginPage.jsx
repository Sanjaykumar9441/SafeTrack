import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';
import toast from 'react-hot-toast';
import { FiLock, FiMail, FiEye, FiEyeOff } from 'react-icons/fi';
import { FaBus } from 'react-icons/fa';

const LoginPage = () => {
  const [tab, setTab] = useState('admin'); // 'admin' | 'driver'

  // Shared form state
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [errors, setErrors] = useState({});

  const { login } = useAuth();
  const navigate = useNavigate();

  // Switch tab — clear form
  const switchTab = (t) => {
    setTab(t);
    setEmail('');
    setPassword('');
    setErrors({});
    setShowPassword(false);
  };

  const validate = () => {
    const e = {};
    if (!email.trim()) e.email = 'Email is required';
    else if (!/\S+@\S+\.\S+/.test(email)) e.email = 'Enter a valid email';
    if (!password.trim()) e.password = 'Password is required';
    else if (password.length < 6) e.password = 'At least 6 characters';
    setErrors(e);
    return Object.keys(e).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;

    setLoading(true);
    try {
      const { role } = await login(email, password);

      if (tab === 'admin') {
        // Admin tab — only allow admin role
        if (role !== 'admin') {
          toast.error('This account is not an admin. Use Driver Login tab.');
          return;
        }
        toast.success('Welcome to SafeTrack Admin Panel!');
        navigate('/dashboard');

      } else {
        // Driver tab — only allow driver role
        if (role !== 'driver') {
          toast.error('This account is not a driver. Use Admin Login tab.');
          return;
        }
        toast.success('Welcome, Driver!');
        navigate('/driver/bus-select');
      }

    } catch (error) {
      const code = error.code;
      let msg = 'Invalid email or password';
      if (code === 'auth/user-not-found') msg = 'No account found with this email';
      if (code === 'auth/wrong-password') msg = 'Incorrect password';
      if (code === 'auth/invalid-credential') msg = 'Invalid email or password';
      if (code === 'auth/too-many-requests') msg = 'Too many attempts. Try later.';
      toast.error(msg);
    } finally {
      setLoading(false);
    }
  };

  const placeholderEmail = tab === 'admin'
    ? 'admin@safetrack.com'
    : 'driver@safetrack.com';

  return (
    <div className="min-h-screen bg-gradient-to-br from-primary-900 via-primary-800 to-primary-700 flex items-center justify-center p-4">

      {/* Background blobs */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-80 h-80 rounded-full bg-primary-600 opacity-20" />
        <div className="absolute -bottom-40 -left-40 w-80 h-80 rounded-full bg-primary-500 opacity-20" />
      </div>

      <div className="relative w-full max-w-md">

        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-white rounded-2xl shadow-lg mb-4">
            <FaBus className="w-8 h-8 text-primary-600" />
          </div>
          <h1 className="text-3xl font-bold text-white">SafeTrack</h1>
          <p className="text-primary-200 mt-1">Smart Bus Safety System</p>
        </div>

        <div className="bg-white rounded-2xl shadow-2xl overflow-hidden">

          {/* Tabs */}
          <div className="flex border-b border-gray-100">
            <button
              onClick={() => switchTab('admin')}
              className={`flex-1 py-4 text-sm font-semibold transition-all ${tab === 'admin'
                  ? 'text-primary-600 border-b-2 border-primary-600 bg-primary-50'
                  : 'text-gray-400 hover:text-gray-600'
                }`}
            >
              🛡 Admin Login
            </button>
            <button
              onClick={() => switchTab('driver')}
              className={`flex-1 py-4 text-sm font-semibold transition-all ${tab === 'driver'
                  ? 'text-yellow-600 border-b-2 border-yellow-500 bg-yellow-50'
                  : 'text-gray-400 hover:text-gray-600'
                }`}
            >
              🚌 Driver Login
            </button>
          </div>

          <div className="p-8">
            <h2 className="text-xl font-semibold text-gray-800 mb-1">
              {tab === 'admin' ? 'Admin Sign In' : 'Driver Sign In'}
            </h2>
            <p className="text-gray-400 text-sm mb-6">
              {tab === 'admin'
                ? 'Access the SafeTrack admin dashboard'
                : 'Access your driver terminal'}
            </p>

            <form onSubmit={handleSubmit} className="space-y-5">

              {/* Email */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Email
                </label>
                <div className="relative">
                  <FiMail className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
                  <input
                    type="email"
                    value={email}
                    onChange={e => { setEmail(e.target.value); setErrors({}); }}
                    placeholder={placeholderEmail}
                    className={`w-full pl-10 pr-4 py-3 border rounded-lg focus:ring-2 focus:border-transparent outline-none transition-all ${tab === 'admin'
                        ? 'focus:ring-primary-500'
                        : 'focus:ring-yellow-400'
                      } ${errors.email ? 'border-red-500 bg-red-50' : 'border-gray-300'}`}
                  />
                </div>
                {errors.email && (
                  <p className="text-red-500 text-xs mt-1">{errors.email}</p>
                )}
              </div>

              {/* Password */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Password
                </label>
                <div className="relative">
                  <FiLock className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={e => { setPassword(e.target.value); setErrors({}); }}
                    placeholder="Enter your password"
                    className={`w-full pl-10 pr-12 py-3 border rounded-lg focus:ring-2 focus:border-transparent outline-none transition-all ${tab === 'admin'
                        ? 'focus:ring-primary-500'
                        : 'focus:ring-yellow-400'
                      } ${errors.password ? 'border-red-500 bg-red-50' : 'border-gray-300'}`}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  >
                    {showPassword ? <FiEyeOff className="w-5 h-5" /> : <FiEye className="w-5 h-5" />}
                  </button>
                </div>
                {errors.password && (
                  <p className="text-red-500 text-xs mt-1">{errors.password}</p>
                )}
              </div>

              {/* Submit */}
              <button
                type="submit"
                disabled={loading}
                className={`w-full text-white font-semibold py-3 rounded-lg transition-all disabled:opacity-50 flex items-center justify-center ${tab === 'admin'
                    ? 'bg-primary-600 hover:bg-primary-700'
                    : 'bg-yellow-400 hover:bg-yellow-500 text-gray-900'
                  }`}
              >
                {loading ? (
                  <>
                    <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2" />
                    Signing in...
                  </>
                ) : (
                  tab === 'admin' ? 'Sign In as Admin' : 'Sign In as Driver'
                )}
              </button>
            </form>
          </div>
        </div>

        <p className="text-center text-primary-300 text-sm mt-6">
          © 2026 SafeTrack — Aditya University ECE
        </p>
      </div>
    </div>
  );
};

export default LoginPage;
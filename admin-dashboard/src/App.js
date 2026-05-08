import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { AuthProvider } from './context/AuthContext';
import { useAuth } from './hooks/useAuth';
import LoginPage from './components/Auth/LoginPage';
import DashboardLayout from './components/Layout/DashboardLayout';
import DashboardHome from './components/Dashboard/DashboardHome';
import CreateBus from './components/Bus/CreateBus';
import BusList from './components/Bus/BusList';
import CreateRoute from './components/Route/CreateRoute';
import RouteList from './components/Route/RouteList';
import AlertsPanel from './components/Alerts/AlertsPanel';
import LiveDataPanel from './components/LiveData/LiveDataPanel';

const ProtectedRoute = ({ children }) => {
  const { admin, loading } = useAuth();

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gray-100">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    );
  }

  if (!admin) {
    return <Navigate to="/login" replace />;
  }

  return children;
};

function AppRoutes() {
  const { admin } = useAuth();

  return (
    <Routes>
      <Route
        path="/login"
        element={admin ? <Navigate to="/dashboard" replace /> : <LoginPage />}
      />

      <Route
        path="/dashboard"
        element={
          <ProtectedRoute>
            <DashboardLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<DashboardHome />} />
        <Route path="buses" element={<BusList />} />
        <Route path="buses/create" element={<CreateBus />} />
        <Route path="routes" element={<RouteList />} />
        <Route path="routes/create" element={<CreateRoute />} />
        <Route path="alerts" element={<AlertsPanel />} />
        <Route path="live-data" element={<LiveDataPanel />} />
      </Route>

      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  );
}

function App() {
  return (
    <AuthProvider>
      <Router>
        <Toaster position="top-right" />
        <AppRoutes />
      </Router>
    </AuthProvider>
  );
}

export default App;
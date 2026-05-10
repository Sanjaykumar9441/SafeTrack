import React, { createContext, useState, useEffect } from 'react';
import { auth, db } from '../firebase';
import {
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
} from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';

export const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null); // { uid, email, name, role }
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      if (firebaseUser) {
        try {
          // Fetch role from Firestore users collection
          const userDoc = await getDoc(doc(db, 'users', firebaseUser.uid));

          if (userDoc.exists()) {
            const data = userDoc.data();
            setUser({
              uid: firebaseUser.uid,
              email: firebaseUser.email,
              name: data.name || firebaseUser.email?.split('@')[0] || 'User',
              role: data.role || 'driver', // 'admin' or 'driver'
            });
          } else {
            // No Firestore doc — treat as driver by default
            setUser({
              uid: firebaseUser.uid,
              email: firebaseUser.email,
              name: firebaseUser.email?.split('@')[0] || 'User',
              role: 'driver',
            });
          }
        } catch (e) {
          // Firestore read failed — still set basic user
          setUser({
            uid: firebaseUser.uid,
            email: firebaseUser.email,
            name: firebaseUser.email?.split('@')[0] || 'User',
            role: 'driver',
          });
        }
      } else {
        setUser(null);
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const login = async (email, password) => {
    const credential = await signInWithEmailAndPassword(auth, email, password);

    // Fetch role immediately after login
    const userDoc = await getDoc(doc(db, 'users', credential.user.uid));
    const role = userDoc.exists() ? userDoc.data().role : 'driver';

    return { user: credential.user, role };
  };

  const logout = async () => {
    await signOut(auth);
    setUser(null);
    // Clear driver session too
    localStorage.removeItem('driver_session');
    localStorage.removeItem('driver_bus');
  };

  // Helpers
  const isAdmin = user?.role === 'admin';
  const isDriver = user?.role === 'driver';

  // Keep 'admin' alias so existing ProtectedRoute in App.js still works
  const admin = isAdmin ? user : null;

  return (
    <AuthContext.Provider value={{
      user,
      admin,        // ← keep this so ProtectedRoute doesn't break
      isAdmin,
      isDriver,
      login,
      logout,
      loading,
    }}>
      {children}
    </AuthContext.Provider>
  );
};
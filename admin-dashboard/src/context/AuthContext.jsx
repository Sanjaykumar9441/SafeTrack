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

      if (!firebaseUser) {
        setUser(null);
        setLoading(false);
        return;
      }

      try {
        const userRef = doc(db, 'users', firebaseUser.uid);
        const userSnap = await getDoc(userRef);

        if (userSnap.exists()) {
          const data = userSnap.data();

          setUser({
            uid: firebaseUser.uid,
            email: firebaseUser.email,
            name: data.name || 'User',
            role: data.role || null,
          });
        } else {
          setUser({
            uid: firebaseUser.uid,
            email: firebaseUser.email,
            name: firebaseUser.email || 'User',
            role: null,
          });
        }

      } catch (error) {
        console.error('Auth Error:', error);

        setUser(null);
      }

      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const login = async (email, password) => {
    const credential = await signInWithEmailAndPassword(
      auth,
      email,
      password
    );

    return { user: credential.user };
  };

  const logout = async () => {
    await signOut(auth);
    setUser(null);
    // Clear driver session too
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
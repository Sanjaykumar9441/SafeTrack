import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: "AIzaSyBTrDjbGYfv2vkRBheq4XjLhqY7jUMqEMs",
  authDomain: "safedrive-144.firebaseapp.com",
  projectId: "safedrive-144",
  storageBucket: "safedrive-144.firebasestorage.app",
  messagingSenderId: "915377574101",
  appId: "1:915377574101:web:3ad362dd20cc87e9cdd25c",
  measurementId: "G-TE1QYJP4QK"
};

const app = initializeApp(firebaseConfig);

export const db = getFirestore(app);
export const auth = getAuth(app);
export default app;

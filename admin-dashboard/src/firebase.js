import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFunctions } from 'firebase/functions';

const firebaseConfig = {
  apiKey: "AIzaSyDzOEZhpQXG-HQUCx0qOD_sRk9Lenpnlp0",
  authDomain: "qr-wallet-1993.firebaseapp.com",
  projectId: "qr-wallet-1993",
  storageBucket: "qr-wallet-1993.firebasestorage.app",
  messagingSenderId: "123632722078",
  appId: "1:123632722078:web:fa3f686dedccc75c7a5b8f",
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const functions = getFunctions(app, 'us-central1');

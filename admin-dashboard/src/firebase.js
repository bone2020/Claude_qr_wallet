import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFunctions } from 'firebase/functions';

const firebaseConfig = {
  apiKey: "AIzaSyDExample", // Replace with your web app config
  authDomain: "qr-wallet-1993.firebaseapp.com",
  projectId: "qr-wallet-1993",
  storageBucket: "qr-wallet-1993.appspot.com",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_WEB_APP_ID",
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const functions = getFunctions(app, 'africa-south1');

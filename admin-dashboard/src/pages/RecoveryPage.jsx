import React, { useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../firebase';

function RecoveryPage() {
  const [targetUid, setTargetUid] = useState('');
  const [otp, setOtp] = useState('');
  const [otpInput, setOtpInput] = useState('');
  const [phonePreview, setPhonePreview] = useState('');
  const [expiresIn, setExpiresIn] = useState(0);
  const [step, setStep] = useState('search'); // search, otp_sent, verified
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');

  const handleSendOTP = async (e) => {
    e.preventDefault();
    if (!targetUid.trim()) return;

    setError('');
    setMessage('');
    setLoading(true);

    try {
      const adminSendRecoveryOTP = httpsCallable(functions, 'adminSendRecoveryOTP');
      const result = await adminSendRecoveryOTP({ targetUid: targetUid.trim() });
      setOtp(result.data.otp);
      setPhonePreview(result.data.phoneNumber);
      setExpiresIn(result.data.expiresInMinutes);
      setStep('otp_sent');
      setMessage('OTP generated successfully.');
    } catch (err) {
      setError(err.message || 'Failed to send OTP.');
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOTP = async (e) => {
    e.preventDefault();
    if (!otpInput.trim()) return;

    setError('');
    setMessage('');
    setLoading(true);

    try {
      const adminVerifyRecoveryOTP = httpsCallable(functions, 'adminVerifyRecoveryOTP');
      await adminVerifyRecoveryOTP({ targetUid: targetUid.trim(), otp: otpInput.trim() });
      setStep('verified');
      setMessage('OTP verified successfully. User identity confirmed.');
    } catch (err) {
      setError(err.message || 'OTP verification failed.');
    } finally {
      setLoading(false);
    }
  };

  const handleReset = () => {
    setTargetUid('');
    setOtp('');
    setOtpInput('');
    setPhonePreview('');
    setExpiresIn(0);
    setStep('search');
    setError('');
    setMessage('');
  };

  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-900 mb-6">Account Recovery</h2>

      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      {message && (
        <div className="mb-4 p-3 bg-green-50 border border-green-200 text-green-700 rounded-lg text-sm">
          {message}
        </div>
      )}

      {step === 'search' && (
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold mb-4">Step 1: Generate Recovery OTP</h3>
          <p className="text-sm text-gray-500 mb-4">
            Enter the user&apos;s UID to generate a recovery OTP. The OTP will be sent to their registered phone number.
          </p>
          <form onSubmit={handleSendOTP} className="flex gap-4">
            <input
              type="text"
              value={targetUid}
              onChange={(e) => setTargetUid(e.target.value)}
              placeholder="User UID"
              className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
            />
            <button
              type="submit"
              disabled={loading}
              className="px-6 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg transition-colors disabled:opacity-50"
            >
              {loading ? 'Generating...' : 'Generate OTP'}
            </button>
          </form>
        </div>
      )}

      {step === 'otp_sent' && (
        <div className="space-y-6">
          <div className="bg-white rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold mb-4">OTP Generated</h3>
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
              <p className="text-sm text-yellow-800">
                <strong>OTP:</strong> <span className="font-mono text-lg">{otp}</span>
              </p>
              <p className="text-sm text-yellow-800 mt-1">
                <strong>Phone:</strong> {phonePreview}
              </p>
              <p className="text-sm text-yellow-800 mt-1">
                <strong>Expires in:</strong> {expiresIn} minutes
              </p>
            </div>
            <p className="text-sm text-gray-500">
              Communicate this OTP to the user through a secure channel. Then verify it below.
            </p>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold mb-4">Step 2: Verify OTP</h3>
            <form onSubmit={handleVerifyOTP} className="flex gap-4">
              <input
                type="text"
                value={otpInput}
                onChange={(e) => setOtpInput(e.target.value)}
                placeholder="Enter OTP from user"
                maxLength={6}
                className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500"
              />
              <button
                type="submit"
                disabled={loading}
                className="px-6 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg transition-colors disabled:opacity-50"
              >
                {loading ? 'Verifying...' : 'Verify OTP'}
              </button>
            </form>
          </div>
        </div>
      )}

      {step === 'verified' && (
        <div className="bg-white rounded-lg shadow p-6">
          <div className="text-center">
            <div className="text-5xl mb-4">✅</div>
            <h3 className="text-lg font-semibold mb-2">Identity Verified</h3>
            <p className="text-gray-500 mb-6">
              The user&apos;s identity has been confirmed via OTP verification.
              You can now proceed with account recovery actions.
            </p>
            <button
              onClick={handleReset}
              className="px-6 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg transition-colors"
            >
              Start New Recovery
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default RecoveryPage;

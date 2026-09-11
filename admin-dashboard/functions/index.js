const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const axios = require('axios');
const twilio = require('twilio');

// Local/deployed .env values are used for the expo deployment. This avoids
// making Firebase Secret Manager (and therefore billing) a prerequisite.
require('dotenv').config();

const GROQ_API_KEY = process.env.GROQ_API_KEY || '';
const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID;
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN;
const TWILIO_FROM_NUMBER = process.env.TWILIO_FROM_NUMBER;
const ENABLE_VOICE_CALLS = String(process.env.ENABLE_VOICE_CALLS || 'false').toLowerCase() === 'true';
const SLACK_WEBHOOKS = {
  police: process.env.SLACK_WEBHOOK_POLICE,
  ambulance: process.env.SLACK_WEBHOOK_AMBULANCE,
  fire: process.env.SLACK_WEBHOOK_FIRE,
};
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID;
const EMERGENCY_CONTACTS = [{ name: 'Police', phone: process.env.EMERGENCY_PHONE_POLICE || '' }];

async function askGroq(prompt, systemMessage) {
  if (!GROQ_API_KEY) throw new Error('GROQ_API_KEY is not configured.');
  const messages = [];
  if (systemMessage) messages.push({ role: 'system', content: systemMessage });
  messages.push({ role: 'user', content: prompt });
  const response = await axios.post(
    'https://api.groq.com/openai/v1/chat/completions',
    { model: 'llama-3.1-8b-instant', messages },
    { headers: { Authorization: `Bearer ${GROQ_API_KEY}`, 'Content-Type': 'application/json' }, timeout: 30000 }
  );
  return response.data.choices?.[0]?.message?.content || '';
}

exports.askAI = onCall({ region: 'asia-south1' }, async (request) => {
  try {
    const prompt = request.data?.prompt || '';
    if (!prompt.trim()) throw new HttpsError('invalid-argument', 'Prompt is required.');
    return { success: true, text: await askGroq(prompt) };
  } catch (error) {
    console.error('Groq Error:', error.response?.data || error.message);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError('internal', error.message || 'Groq AI failed.');
  }
});

exports.generateRouteAdvice = onCall({ region: 'asia-south1' }, async (request) => {
  try {
    const { currentLocation = 'Unknown', destination = 'Unknown', nextStop = 'Unknown' } = request.data || {};
    const advice = await askGroq(
      `A bus is currently near ${currentLocation}.\nDestination: ${destination}.\nNext stop: ${nextStop}.\n\nSuggest a short safe rerouting or traffic-management recommendation for the driver.`,
      'You are an AI transportation safety assistant for public buses.'
    );
    return { success: true, advice };
  } catch (error) {
    console.error('AI Route Advice Error:', error.response?.data || error.message);
    throw new HttpsError('internal', 'Failed to generate route advice');
  }
});

async function makeCall(toNumber) {
  if (!ENABLE_VOICE_CALLS) return { sid: null, status: 'disabled' };
  if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_FROM_NUMBER || !toNumber) {
    throw new Error('Twilio voice calls are enabled but configuration is incomplete.');
  }
  const client = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);
  const twiml = '<Response><Say voice="woman">This is an emergency alert from SafeTrack Bus Safety System. Please respond immediately.</Say><Pause length="1"/><Say voice="woman">This is an emergency alert from SafeTrack Bus Safety System. Please respond immediately.</Say></Response>';
  return client.calls.create({ from: TWILIO_FROM_NUMBER, to: toNumber, twiml });
}

async function sendSlackAlert({ alertType, busNumber, severity, latitude, longitude, message, alertId }) {
  const hooks = Object.entries(SLACK_WEBHOOKS).filter(([, value]) => Boolean(value));
  if (!hooks.length) return { status: 'skipped', reason: 'No Slack webhook configured' };
  const hasLocation = Number(latitude) !== 0 && Number(longitude) !== 0;
  const mapsUrl = hasLocation ? `https://maps.google.com/?q=${latitude},${longitude}` : null;
  const payload = {
    text: `SAFETRACK EMERGENCY — ${alertType} on Bus ${busNumber}`,
    attachments: [{ color: severity === 'CRITICAL' ? '#FF0000' : '#FF6600', blocks: [
      { type: 'header', text: { type: 'plain_text', text: `${alertType} ALERT — Bus ${busNumber}`, emoji: true } },
      { type: 'section', fields: [{ type: 'mrkdwn', text: `*Severity:*\n${severity}` }, { type: 'mrkdwn', text: `*Message:*\n${message}` }] },
      { type: 'section', text: { type: 'mrkdwn', text: hasLocation ? `*Location:* ${latitude}, ${longitude}` : '*Location:* Not available' } },
      ...(mapsUrl ? [{ type: 'actions', elements: [{ type: 'button', text: { type: 'plain_text', text: 'Open Google Maps' }, url: mapsUrl, style: 'danger' }] }] : []),
      { type: 'context', elements: [{ type: 'mrkdwn', text: `Alert ID: ${alertId || 'N/A'} | SafeTrack` }] },
    ] }],
  };
  const results = await Promise.allSettled(hooks.map(([name, url]) => axios.post(url, payload, { headers: { 'Content-Type': 'application/json' }, timeout: 15000 }).then(() => ({ channel: name, status: 'sent' }))));
  const failures = results.filter((r) => r.status === 'rejected').map((r) => r.reason?.message || 'Slack request failed');
  return failures.length ? { status: 'partial', failures } : { status: 'sent', channels: hooks.map(([name]) => name) };
}

async function sendTelegramAlert({ alertType, busNumber, severity, latitude, longitude, message }) {
  if (!TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) throw new Error('Telegram is not configured: set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID in .env.');
  const hasLocation = Number(latitude) !== 0 && Number(longitude) !== 0;
  const location = hasLocation ? `https://maps.google.com/?q=${latitude},${longitude}` : 'Location not available';
  const text = `🚨 SAFETRACK EMERGENCY ALERT\n\nBus: ${busNumber}\nAlert: ${alertType}\nSeverity: ${severity}\n\nLocation: ${location}\n\nMessage: ${message}`;
  return (await axios.post(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, { chat_id: TELEGRAM_CHAT_ID, text, disable_web_page_preview: false }, { timeout: 15000 })).data;
}

exports.sendEmergencyAlert = onRequest({ region: 'us-central1', invoker: 'public', cors: true, timeoutSeconds: 60 }, async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ success: false, error: 'POST required' });
  const body = req.body || {};
  const { alertType = 'EMERGENCY', busNumber = 'Unknown', severity = 'CRITICAL', latitude = 0, longitude = 0, message = 'Emergency detected', alertId = '' } = body;
  const results = { calls: [], slack: null, telegram: null, errors: [] };

  if (ENABLE_VOICE_CALLS) {
    for (const contact of EMERGENCY_CONTACTS.filter((c) => c.phone)) {
      try {
        const call = await makeCall(contact.phone);
        results.calls.push({ contact: contact.name, phone: contact.phone, callSid: call.sid, status: call.status });
      } catch (error) {
        results.errors.push(`Call failed to ${contact.name}: ${error.message}`);
      }
    }
  } else {
    results.calls.push({ status: 'disabled', reason: 'ENABLE_VOICE_CALLS is not true' });
  }

  try { results.slack = await sendSlackAlert({ alertType, busNumber, severity, latitude, longitude, message, alertId }); }
  catch (error) { results.errors.push(`Slack failed: ${error.message}`); }
  try { results.telegram = await sendTelegramAlert({ alertType, busNumber, severity, latitude, longitude, message }); }
  catch (error) { results.errors.push(`Telegram failed: ${error.message}`); }

  const notificationSuccess = results.errors.length === 0 && (
    results.telegram?.ok === true || results.slack?.status === 'sent' || results.calls.some((c) => c.status === 'queued' || c.status === 'sent')
  );
  return res.status(200).json({ success: true, alertId, results, notificationSuccess });
});

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const axios = require("axios");
const twilio = require("twilio");

require("dotenv").config();
const GROQ_API_KEY = process.env.GROQ_API_KEY;

// all credentials loaded from environment variables (set via Firebase Functions config or .env)
const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID;
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN;
const TWILIO_FROM_NUMBER = process.env.TWILIO_FROM_NUMBER;

const SLACK_WEBHOOKS = {
  police: process.env.SLACK_WEBHOOK_POLICE,
  ambulance: process.env.SLACK_WEBHOOK_AMBULANCE,
  fire: process.env.SLACK_WEBHOOK_FIRE,
};

const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID;

// phone numbers to call during emergencies
const EMERGENCY_CONTACTS = [
  { name: "Police", phone: process.env.EMERGENCY_PHONE_POLICE || "+917095009441" },
];

exports.askAI = onCall(
  { region: "asia-south1" },
  async (request) => {
    try {
      const prompt = request.data.prompt;
      console.log("Prompt:", prompt);
      console.log("Groq Key Exists:", !!GROQ_API_KEY);

      const response = await axios.post(
        "https://api.groq.com/openai/v1/chat/completions",
        {
          model: "llama-3.1-8b-instant",
          messages: [
            {
              role: "user",
              content: prompt,
            },
          ],
        },
        {
          headers: {
            Authorization:
              `Bearer ${GROQ_API_KEY}`,
            "Content-Type": "application/json",
          },
        }
      );

      const text =
        response.data.choices[0].message.content;

      return {
        success: true,
        text: text,
      };
    } catch (error) {
      console.error(
        "Groq Error Full:",
        error.response?.data ||
        error.message ||
        error
      );

      throw new HttpsError(
        "internal",
        "Groq AI failed."
      );
    }
  }
);

// initiate a voice call using Twilio with a TwiML emergency message
async function makeCall(toNumber) {
  const client = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);
  const twiml =
    `<Response>
       <Say voice="woman">
         This is an emergency alert from SafeTrack Bus Safety System.
         An accident or fire has been detected on a bus.
         Please respond immediately to the location.
         This message will repeat.
       </Say>
       <Pause length="1"/>
       <Say voice="woman">
         This is an emergency alert from SafeTrack Bus Safety System.
         An accident or fire has been detected on a bus.
         Please respond immediately to the location.
       </Say>
     </Response>`;

  return await client.calls.create({ from: TWILIO_FROM_NUMBER, to: toNumber, twiml });
}

// send a rich-formatted alert to all Slack emergency channels
async function sendSlackAlert({ alertType, busNumber, severity, latitude, longitude, message, alertId }) {
  const hasLocation = latitude !== 0 && longitude !== 0;
  const mapsUrl = hasLocation ? `https://maps.google.com/?q=${latitude},${longitude}` : null;
  const colorMap = { CRITICAL: "#FF0000", HIGH: "#FF6600", MEDIUM: "#FFA500", LOW: "#0000FF" };

  const slackPayload = {
    text: `SAFETRACK EMERGENCY — ${alertType} on Bus ${busNumber}`,
    attachments: [{
      color: colorMap[severity] || "#FF0000",
      blocks: [
        { type: "header", text: { type: "plain_text", text: `${alertType} ALERT — Bus ${busNumber}`, emoji: true } },
        {
          type: "section", fields: [
            { type: "mrkdwn", text: `*Alert Type:*\n${alertType}` },
            { type: "mrkdwn", text: `*Bus Number:*\n${busNumber}` },
            { type: "mrkdwn", text: `*Severity:*\n${severity}` },
            { type: "mrkdwn", text: `*Message:*\n${message}` },
          ]
        },
        { type: "divider" },
        {
          type: "section",
          text: { type: "mrkdwn", text: hasLocation ? `*Location:* ${latitude.toFixed(4)}, ${longitude.toFixed(4)}` : "*Location:* Not available" },
          ...(hasLocation && { accessory: { type: "button", text: { type: "plain_text", text: "Open in Google Maps", emoji: true }, url: mapsUrl, style: "primary" } }),
        },
        {
          type: "actions", elements: [
            ...(hasLocation ? [{ type: "button", text: { type: "plain_text", text: "View Location", emoji: true }, url: mapsUrl, style: "primary" }] : []),
            { type: "button", text: { type: "plain_text", text: "View Bus Details", emoji: true }, url: `https://safedrive-144.web.app/dashboard/alerts`, style: "danger" },
          ]
        },
        { type: "context", elements: [{ type: "mrkdwn", text: `Alert ID: ${alertId} | SafeTrack` }] },
      ],
    }],
  };

  const responses = await Promise.all([
    axios.post(SLACK_WEBHOOKS.police, slackPayload, { headers: { "Content-Type": "application/json" } }),
    axios.post(SLACK_WEBHOOKS.ambulance, slackPayload, { headers: { "Content-Type": "application/json" } }),
    axios.post(SLACK_WEBHOOKS.fire, slackPayload, { headers: { "Content-Type": "application/json" } }),
  ]);
  return responses.map(r => r.data);
}

// send a plaintext alert to the Telegram emergency group
async function sendTelegramAlert({ alertType, busNumber, severity, latitude, longitude, message }) {
  const text =
    `SAFETRACK EMERGENCY ALERT\n\n` +
    `Bus: ${busNumber}\nAlert: ${alertType}\nSeverity: ${severity}\n\n` +
    `Location:\nhttps://maps.google.com/?q=${latitude},${longitude}\n\n` +
    `Message:\n${message}`;

  return (await axios.post(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, { chat_id: TELEGRAM_CHAT_ID, text })).data;
}

// main HTTP endpoint — called by the admin dashboard to dispatch emergency notifications
exports.sendEmergencyAlert = onRequest(
  { invoker: "public", cors: true },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") { res.status(405).json({ error: "Method not allowed" }); return; }

    const { alertType = "EMERGENCY", busNumber = "Unknown", severity = "CRITICAL",
      latitude = 0, longitude = 0, message = "Emergency detected", alertId = "" } = req.body;

    const results = { calls: [], slack: null, telegram: null, errors: [] };

    for (const contact of EMERGENCY_CONTACTS) {
      try {
        const call = await makeCall(contact.phone);
        results.calls.push({ contact: contact.name, phone: contact.phone, callSid: call.sid, status: call.status });
        console.log(`Call initiated to ${contact.name} — SID: ${call.sid}`);
      } catch (err) {
        results.errors.push(`Call failed to ${contact.name}: ${err.message}`);
        console.error(results.errors[results.errors.length - 1]);
      }
    }

    try {
      await sendSlackAlert({ alertType, busNumber, severity, latitude, longitude, message, alertId });
      results.slack = { status: "sent" };
    } catch (err) { results.errors.push(`Slack failed: ${err.message}`); }

    try {
      await sendTelegramAlert({ alertType, busNumber, severity, latitude, longitude, message });
      results.telegram = { status: "sent" };
    } catch (err) { results.errors.push(`Telegram failed: ${err.message}`); }

    res.set("Access-Control-Allow-Origin", "*");
    res.status(200).json({ success: true, alertId, results });
  }
);
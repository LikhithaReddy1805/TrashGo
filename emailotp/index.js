const functions = require("firebase-functions");
const nodemailer = require("nodemailer");

// ---- Configure your Brevo SMTP transporter ----
const transporter = nodemailer.createTransport({
  host: "smtp-relay.brevo.com",   // Brevo SMTP server
  port: 587,                      // Port (587 recommended)
  secure: false,                  // false for TLS
  auth: {
    user: "chaithanyashringar@gmail.com",  // Example: your email or SMTP login
    pass: process.env.BREVO_SMTP_KEY,  // From Brevo → SMTP → Password
  },
});

// ---- Cloud Function to send OTP ----
exports.sendEmailOtp = functions.https.onCall(async (data, context) => {
  const email = data.email;

  if (!email) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Email is required."
    );
  }

  // Generate 6-digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();

  const mailOptions = {
    from: "chaithanyashringar@gmail.com",     // Example: chaithanyashringar@gmail.com
    to: email,
    subject: "Your OTP Code",
    text: `Your OTP is: ${otp}`,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log("OTP sent to:", email);

    return { success: true, otp: otp }; // Return OTP (store in Firestore if needed)
  } catch (error) {
    console.error("Error sending email:", error);
    throw new functions.https.HttpsError("internal", "Failed to send OTP");
  }
});

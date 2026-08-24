import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

export const onMessageCreated = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const defaultIcon = "https://cdn-icons-png.flaticon.com/512/149/149071.png";
    const newMessage = snap.data();
    const chatId = event.params.chatId;

    const senderId = newMessage.senderId;
    // content might be encrypted, but could be useful if decrypted later. Ignoring for now.
    // const content = newMessage.content;

    try {
      // 1. Get Chat details to find the recipient
      const chatDoc = await db.collection("chats").doc(chatId).get();
      if (!chatDoc.exists) {
        console.log("Chat document not found:", chatId);
        return null;
      }
      
      const chatData = chatDoc.data()!;
      // Assuming chat string stores both UIDs or has candidateId and recruiterId
      const candidateId = chatData.candidateId;
      const recruiterId = chatData.recruiterId;

      if (!candidateId || !recruiterId) {
        console.log("Missing participant IDs in chat");
        return null;
      }

      const isSenderRecruiter = senderId === recruiterId;
      const recipientId = isSenderRecruiter ? candidateId : recruiterId;

      // 2. Get sender profile for name and image
      let senderName = "User";
      let senderImageUrl = defaultIcon;
      let jobTitle = "Job";

      if (chatData.jobId) {
         try {
           const jobDoc = await db.collection("jobs").doc(chatData.jobId).get();
           if (jobDoc.exists) {
             jobTitle = jobDoc.data()?.roleName || "Job";
           }
         } catch(e) { }
      }

      if (isSenderRecruiter) {
        const recruiterDoc = await db.collection("recruiters").doc(senderId).get();
        if (recruiterDoc.exists) {
          senderName = recruiterDoc.data()?.fullName || "Recruiter";
          senderImageUrl = recruiterDoc.data()?.photoUrl || defaultIcon;
        }
      } else {
        const candidateDoc = await db.collection("candidates").doc(senderId).get();
        if (candidateDoc.exists) {
          senderName = candidateDoc.data()?.firstName 
            ? `${candidateDoc.data()?.firstName} ${candidateDoc.data()?.lastName}`.trim()
            : "Candidate";
          senderImageUrl = candidateDoc.data()?.photoUrl || defaultIcon;
        }
      }

      // 3. Get recipient FCM Token
      let fcmToken = null;
      if (isSenderRecruiter) {
        // Recipient is candidate
        const candidateDoc = await db.collection("candidates").doc(recipientId).get();
        fcmToken = candidateDoc.data()?.fcmToken;
      } else {
        // Recipient is recruiter
        const recruiterDoc = await db.collection("recruiters").doc(recipientId).get();
        fcmToken = recruiterDoc.data()?.fcmToken;
      }

      // 4. Also write to notification_recruter / notification_candidate if needed
      // (The Flutter app is already listening to these collections)
      if (isSenderRecruiter) {
         // Create for candidate
         await db.collection("notification_candidate").add({
           userId: recipientId,
           type: 'message',
           title: `New Message from ${senderName}`,
           content: 'You have received a new message.',
           timestamp: admin.firestore.FieldValue.serverTimestamp(),
           isRead: false,
           payloadId: chatId,
           jobId: chatData.jobId,
           candidateId: candidateId,
           recruiterId: recruiterId,
         });
      } else {
         // Create for recruiter
         await db.collection("notification_recruter").add({
           recruiterId: recipientId,
           type: 'message',
           title: `New Message from ${senderName}`,
           content: 'You have received a new message.',
           timestamp: admin.firestore.FieldValue.serverTimestamp(),
           isRead: false,
           payloadId: chatId,
           jobId: chatData.jobId,
           candidateId: candidateId,
           candidateName: senderName,
           candidateImageUrl: senderImageUrl,
           jobTitle: jobTitle
         });
      }

      if (!fcmToken) {
        console.log(`No FCM token found for user ${recipientId}`);
        return null;
      }

      // 5. Send FCM Push Notification
      const payload = {
        notification: {
          title: `New Message from ${senderName}`,
          body: 'You have received a new message.',
          image: senderImageUrl,
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: "chat",
          chatId: chatId,
          senderName: senderName,
          otherUserId: senderId,
        },
        token: fcmToken,
      };

      await admin.messaging().send(payload);
      console.log(`Successfully sent notification to ${recipientId}`);

    } catch (error) {
      console.error("Error processing notification:", error);
    }

    return null;
  });

export const generateJobDescription = onCall(
  { secrets: ["GEMINI_API_KEY"] },
  async (request) => {
    // 1. Authentication Check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const userId = request.auth.uid;

    try {
      // 2. Authorization Check (Recruiter only)
      const recruiterDoc = await db.collection("recruiters").doc(userId).get();
      if (!recruiterDoc.exists) {
        throw new HttpsError("permission-denied", "Only authenticated recruiters are authorized to generate job descriptions.");
      }

      // 3. Payload and Input Validation
      const data = request.data;
      if (!data) {
        throw new HttpsError("invalid-argument", "Missing request payload.");
      }

      const { role, skills } = data;

      if (!role || typeof role !== "string" || role.trim().length === 0) {
        throw new HttpsError("invalid-argument", "Role is required and must be a non-empty string.");
      }
      if (role.length > 100) {
        throw new HttpsError("invalid-argument", "Job role is too long (maximum 100 characters).");
      }

      if (!skills || !Array.isArray(skills)) {
        throw new HttpsError("invalid-argument", "Skills must be provided as a list.");
      }
      if (skills.length > 20) {
        throw new HttpsError("invalid-argument", "Too many skills provided (maximum 20).");
      }

      for (let i = 0; i < skills.length; i++) {
        const skill = skills[i];
        if (typeof skill !== "string") {
          throw new HttpsError("invalid-argument", `Skill at index ${i} must be a string.`);
        }
        if (skill.trim().length === 0) {
          throw new HttpsError("invalid-argument", `Skill at index ${i} cannot be empty.`);
        }
        if (skill.length > 50) {
          throw new HttpsError("invalid-argument", `Skill "${skill}" is too long (maximum 50 characters).`);
        }
      }

      // 4. Secure API Key Retrieval
      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey || apiKey.trim().length === 0) {
        console.error("GEMINI_API_KEY secret is not configured on the backend.");
        throw new HttpsError("failed-precondition", "AI service is currently misconfigured.");
      }

      // 5. Configurable Model Name (Default to gemini-3.5-flash)
      const model = process.env.GEMINI_MODEL || "gemini-3.5-flash";

      const prompt = `Generate a job description for the role of "${role.trim()}".
Key skills involved: ${skills.map(s => s.trim()).join(', ')}.

Please provide the output in the following JSON format ONLY, without any markdown formatting block:
{
  "description": "A compelling 3-4 sentence job description.",
  "responsibilities": ["Responsibility 1", "Responsibility 2", "Responsibility 3", "Responsibility 4", "Responsibility 5", "Responsibility 6"],
  "requirements": ["Requirement 1", "Requirement 2", "Requirement 3", "Requirement 4", "Requirement 5", "Requirement 6"]
}
Make the tone professional and exciting.`;

      // 6. Invoke Gemini API via standard Fetch
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            contents: [
              {
                parts: [
                  {
                    text: prompt,
                  },
                ],
              },
            ],
            generationConfig: {
              responseMimeType: "application/json",
            },
          }),
        }
      );

      if (!response.ok) {
        const errText = await response.text().catch(() => "");
        console.error(`Gemini API returned status ${response.status}: ${errText}`);
        throw new HttpsError("internal", "Failed to generate job description from AI service.");
      }

      const responseData: any = await response.json();
      const responseText = responseData?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!responseText || typeof responseText !== "string") {
        console.error("Gemini API response did not contain text content:", JSON.stringify(responseData));
        throw new HttpsError("internal", "Received invalid output format from AI service.");
      }

      // 7. Parse and Validate Response format
      let cleanJson = responseText.trim();
      if (cleanJson.startsWith("```")) {
        cleanJson = cleanJson
          .replace(/^```json\s*/i, "")
          .replace(/^```\s*/, "")
          .replace(/```$/, "")
          .trim();
      }

      let parsedData: any;
      try {
        parsedData = JSON.parse(cleanJson);
      } catch (e: any) {
        console.error("Failed to parse Gemini response as JSON. Raw text:", responseText, "Error:", e);
        throw new HttpsError("internal", "AI generated a malformed response format. Please try again.");
      }

      const description = parsedData.description;
      const responsibilities = parsedData.responsibilities;
      const requirements = parsedData.requirements;

      if (typeof description !== "string" || !description.trim()) {
        console.error("Parsed response missing description field:", parsedData);
        throw new HttpsError("internal", "AI description was empty or malformed.");
      }

      if (!Array.isArray(responsibilities)) {
        console.error("Parsed response responsibilities field is not an array:", parsedData);
        throw new HttpsError("internal", "AI responsibilities were empty or malformed.");
      }

      if (!Array.isArray(requirements)) {
        console.error("Parsed response requirements field is not an array:", parsedData);
        throw new HttpsError("internal", "AI requirements were empty or malformed.");
      }

      return {
        description: description.trim(),
        responsibilities: responsibilities.map((r: any) => String(r).trim()).filter(Boolean),
        requirements: requirements.map((r: any) => String(r).trim()).filter(Boolean),
      };

    } catch (error: any) {
      // Avoid leaking internal errors (except HttpsError which is intentional)
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Unhandled error in generateJobDescription:", error);
      throw new HttpsError("internal", "An error occurred while generating the job description.");
    }
  }
);

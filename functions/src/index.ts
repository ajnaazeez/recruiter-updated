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
      const apiKey = (process.env.GEMINI_API_KEY || "").trim();
      if (!apiKey) {
        console.error("GEMINI_API_KEY secret is not configured on the backend.");
        throw new HttpsError("failed-precondition", "AI service is currently misconfigured.");
      }

      // 5. Configurable Model Name (Default to gemini-3.6-flash)
      const model = process.env.GEMINI_MODEL || "gemini-3.6-flash";

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


export const bulkPostJobs = onCall(
  async (request) => {
    // 1. Authentication Check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const userId = request.auth.uid;
    const { jobs } = request.data;

    if (!jobs || !Array.isArray(jobs)) {
      throw new HttpsError("invalid-argument", "Jobs list must be provided as an array.");
    }

    try {
      // 2. Role check in users collection
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists || userDoc.data()?.role !== "recruiter") {
        throw new HttpsError("permission-denied", "Unauthorized. Only recruiters can perform this action.");
      }

      // 3. Fetch recruiter profile and verify subscription
      const recruiterDoc = await db.collection("recruiters").doc(userId).get();
      if (!recruiterDoc.exists) {
        throw new HttpsError("permission-denied", "Recruiter profile details not found.");
      }

      const recruiterData = recruiterDoc.data() || {};
      const isSubscribed = recruiterData.isSubscribed || false;
      const companyId = recruiterData.companyId || "";

      if (!isSubscribed) {
        throw new HttpsError("permission-denied", "Your account is not subscribed. Bulk job posting is disabled.");
      }

      if (!companyId) {
        throw new HttpsError("failed-precondition", "Recruiter is not linked to any company profile.");
      }

      // 4. Fetch company profile to retrieve name & logo
      const companyDoc = await db.collection("companies").doc(companyId).get();
      let companyName = "";
      let companyLogoUrl = "";
      if (companyDoc.exists) {
        const companyData = companyDoc.data() || {};
        companyName = companyData.companyName || "";
        companyLogoUrl = companyData.logoUrl || companyData.companyLogoUrl || "";
      }

      // 5. Generate and batch write jobs
      const postedAt = admin.firestore.Timestamp.now();
      const expiresAt = admin.firestore.Timestamp.fromDate(
        new Date(postedAt.toDate().getTime() + 30 * 24 * 60 * 60 * 1000)
      );

      const batch = db.batch();
      let count = 0;

      for (const job of jobs) {
        const jobId = db.collection("jobs").doc().id;

        const jobDocData = {
          jobId: jobId,
          companyId: companyId,
          recruiterId: userId,
          roleId: "custom",
          roleName: job.roleName || "",
          designationId: "custom",
          designationName: job.roleName || "",
          experienceLevel: job.experienceLevel || "Fresher",
          employmentType: job.employmentType || "Full-Time",
          workMode: job.workMode || "Onsite",
          jobLocation: {
            city: job.jobLocation?.city || "",
            state: job.jobLocation?.state || "",
            country: job.jobLocation?.country || "",
          },
          vacancies: parseInt(job.vacancies) || 1,
          officeCount: parseInt(job.officeCount) || 1,
          experienceRequired: {
            minYears: parseInt(job.experienceRequired?.minYears) || 0,
            maxYears: parseInt(job.experienceRequired?.maxYears) || 0,
          },
          salary: {
            min: parseFloat(job.salary?.min) || 0.0,
            max: parseFloat(job.salary?.max) || 0.0,
            currency: job.salary?.currency || "INR",
            type: job.salary?.type || "CTC",
          },
          skillsRequired: Array.isArray(job.skillsRequired) ? job.skillsRequired : [],
          mustHaveSkills: [],
          niceToHaveSkills: [],
          jobDescription: job.jobDescription || "",
          responsibilities: Array.isArray(job.responsibilities) ? job.responsibilities : [],
          requirements: Array.isArray(job.requirements) ? job.requirements : [],
          interviewProcess: [],
          extraQuestions: [],
          status: "active",
          visibility: "public",
          postedAt: postedAt,
          expiresAt: expiresAt,
          companyName: companyName,
          companyLogoUrl: companyLogoUrl,
        };

        const jobRef = db.collection("jobs").doc(jobId);
        batch.set(jobRef, jobDocData);
        count++;
      }

      if (count > 0) {
        await batch.commit();
      }

      return {
        success: true,
        successCount: count,
        message: "Successfully created job posts.",
      };
    } catch (error: any) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Unhandled error in bulkPostJobs:", error);
      throw new HttpsError("internal", `An error occurred while bulk posting: ${error.message}`);
    }
  }
);

export const enhanceText = onCall(
  { secrets: ["GEMINI_API_KEY"], region: "us-central1" },
  async (request) => {
    // 1. Authentication Check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const userId = request.auth.uid;

    try {
      // 2. Authorization Check (Candidate verification)
      const candidateDoc = await db.collection("candidates").doc(userId).get();
      if (!candidateDoc.exists) {
        throw new HttpsError("permission-denied", "Candidate profile not found or unauthorized.");
      }

      // 3. Payload and Input Validation
      const data = request.data;
      if (!data) {
        throw new HttpsError("invalid-argument", "Missing request payload.");
      }

      const { text, type, context } = data;

      if (!text || typeof text !== "string" || text.trim().length === 0) {
        throw new HttpsError("invalid-argument", "Text is required and must be a non-empty string.");
      }
      if (text.length > 4000) {
        throw new HttpsError("invalid-argument", "Input text is too long (maximum 4000 characters).");
      }

      const title = context?.title && typeof context.title === "string" ? context.title.slice(0, 200).trim() : "";
      const company = context?.company && typeof context.company === "string" ? context.company.slice(0, 200).trim() : "";
      const role = context?.role && typeof context.role === "string" ? context.role.slice(0, 200).trim() : "";

      // 4. Secure API Key Retrieval
      const apiKey = (process.env.GEMINI_API_KEY || "").trim();
      if (!apiKey) {
        console.error("GEMINI_API_KEY secret is not configured on the backend.");
        throw new HttpsError("failed-precondition", "AI service is currently misconfigured.");
      }

      // 5. Model Selection
      const model = process.env.GEMINI_MODEL || "gemini-3.6-flash";

      // 6. Build Prompt
      let prompt = "";
      if (type === "summary") {
        prompt = `Enhance this professional summary/bio for a candidate job profile. Headline: "${title}". Current Description: "${text.trim()}". Make it compelling, professional, and highlight key strengths. Return ONLY the enhanced description text without markdown blocks, commentary, or quotes.`;
      } else if (type === "experience") {
        prompt = `Enhance this job description for a candidate resume. Job Title: "${title}", Company: "${company}". Current Description: "${text.trim()}". Make it professional, focusing on achievements and responsibilities. Return ONLY the enhanced description text without markdown blocks, commentary, or quotes.`;
      } else if (type === "project") {
        prompt = `Enhance this project description for a candidate portfolio. Title: "${title}", Role: "${role}". Current Description: "${text.trim()}". Make it professional, highlighting technical challenges and outcomes. Return ONLY the enhanced description text without markdown blocks, commentary, or quotes.`;
      } else {
        prompt = `Enhance the following professional description for a resume/portfolio profile. Text: "${text.trim()}". Make it concise, professional, and impactful. Return ONLY the enhanced text without markdown blocks, commentary, or quotes.`;
      }

      // 7. Invoke Gemini REST API
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
              temperature: 0.7,
            },
          }),
        }
      );

      if (!response.ok) {
        const errText = await response.text().catch(() => "");
        console.error(`Gemini API returned status ${response.status}: ${errText}`);
        throw new HttpsError("internal", "Failed to generate enhanced text from AI service.");
      }

      const responseData: any = await response.json();
      const responseText = responseData?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!responseText || typeof responseText !== "string") {
        console.error("Gemini API response did not contain text content:", JSON.stringify(responseData));
        throw new HttpsError("internal", "Received invalid output from AI service.");
      }

      let enhancedText = responseText.trim();
      if (enhancedText.startsWith("```")) {
        enhancedText = enhancedText
          .replace(/^```[a-zA-Z]*\s*/, "")
          .replace(/```$/, "")
          .trim();
      }
      if (enhancedText.startsWith('"') && enhancedText.endsWith('"') && enhancedText.length > 2) {
        enhancedText = enhancedText.slice(1, -1).trim();
      }

      return {
        enhancedText,
      };
    } catch (error: any) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Unhandled error in enhanceText:", error);
      throw new HttpsError("internal", "An error occurred while enhancing text.");
    }
  }
);

export const generateAssessmentQuestions = onCall(
  { secrets: ["GEMINI_API_KEY"], region: "us-central1" },
  async (request) => {
    // 1. Authentication Check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const userId = request.auth.uid;

    try {
      // 2. Authorization Check (Candidate verification)
      const candidateDoc = await db.collection("candidates").doc(userId).get();
      if (!candidateDoc.exists) {
        throw new HttpsError("permission-denied", "Candidate profile not found or unauthorized.");
      }

      // 3. Payload and Input Validation
      const data = request.data;
      if (!data) {
        throw new HttpsError("invalid-argument", "Missing request payload.");
      }

      const { skill, difficulty = "Medium", count = 15 } = data;

      if (!skill || typeof skill !== "string" || skill.trim().length === 0) {
        throw new HttpsError("invalid-argument", "Skill is required and must be a non-empty string.");
      }
      if (skill.length > 100) {
        throw new HttpsError("invalid-argument", "Skill name is too long (maximum 100 characters).");
      }

      const validDifficulties = ["Easy", "Medium", "Hard"];
      const validatedDifficulty = validDifficulties.includes(difficulty) ? difficulty : "Medium";

      const questionCount = typeof count === "number" && count >= 1 && count <= 30 ? Math.floor(count) : 15;

      // 4. Secure API Key Retrieval
      const apiKey = (process.env.GEMINI_API_KEY || "").trim();
      if (!apiKey) {
        console.error("GEMINI_API_KEY secret is not configured on the backend.");
        throw new HttpsError("failed-precondition", "AI service is currently misconfigured.");
      }

      // 5. Model Selection
      const model = process.env.GEMINI_MODEL || "gemini-3.6-flash";

      const prompt = `Generate ${questionCount} multiple-choice questions for a "${skill.trim()}" assessment.
Difficulty level: ${validatedDifficulty}.

The output must be a valid JSON array of objects.
Each object must have the following structure:
{
  "question": "The question text",
  "options": ["Option A", "Option B", "Option C", "Option D"],
  "correctAnswerIndex": 0
}

Ensure the questions are relevant to ${skill.trim()} and match the ${validatedDifficulty} difficulty.
"options" must have exactly 4 strings.
"correctAnswerIndex" must be an integer from 0 to 3 indicating the correct option.
Do not include any markdown formatting like \`\`\`json ... \`\`\`, just the raw JSON array.`;

      // 6. Invoke Gemini REST API
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
              temperature: 0.7,
              responseMimeType: "application/json",
            },
          }),
        }
      );

      if (!response.ok) {
        const errText = await response.text().catch(() => "");
        console.error(`Gemini API returned status ${response.status}: ${errText}`);
        throw new HttpsError("internal", "Failed to generate assessment questions from AI service.");
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

      let parsedList: any[];
      try {
        parsedList = JSON.parse(cleanJson);
      } catch (e: any) {
        console.error("Failed to parse Gemini response as JSON. Raw text:", responseText, "Error:", e);
        throw new HttpsError("internal", "AI generated a malformed response format. Please try again.");
      }

      if (!Array.isArray(parsedList) || parsedList.length === 0) {
        console.error("Parsed response is not a non-empty array:", parsedList);
        throw new HttpsError("internal", "AI failed to generate valid assessment questions.");
      }

      const now = Date.now();
      const sanitizedQuestions = [];

      for (let i = 0; i < parsedList.length; i++) {
        const item = parsedList[i];
        if (!item || typeof item !== "object") continue;

        const questionText = typeof item.question === "string" ? item.question.trim() : "";
        const options = Array.isArray(item.options) ? item.options.map((opt: any) => String(opt).trim()).filter(Boolean) : [];
        let correctIndex = typeof item.correctAnswerIndex === "number" ? Math.floor(item.correctAnswerIndex) : 0;

        if (!questionText || options.length < 2) continue;
        if (correctIndex < 0 || correctIndex >= options.length) correctIndex = 0;

        sanitizedQuestions.push({
          id: `${skill.toLowerCase().replace(/[^a-z0-9]/g, "_")}_ai_${now}_${i}`,
          question: questionText,
          options: options,
          correctAnswerIndex: correctIndex,
          skill: skill.trim(),
          difficulty: validatedDifficulty,
        });
      }

      if (sanitizedQuestions.length === 0) {
        throw new HttpsError("internal", "AI generated zero valid questions.");
      }

      return {
        questions: sanitizedQuestions.slice(0, questionCount),
      };
    } catch (error: any) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Unhandled error in generateAssessmentQuestions:", error);
      throw new HttpsError("internal", "An error occurred while generating assessment questions.");
    }
  }
);

export const getRelatedSkills = onCall(
  { secrets: ["GEMINI_API_KEY"], region: "us-central1" },
  async (request) => {
    // 1. Authentication Check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const userId = request.auth.uid;

    try {
      // 2. Authorization Check (Candidate verification)
      const candidateDoc = await db.collection("candidates").doc(userId).get();
      if (!candidateDoc.exists) {
        throw new HttpsError("permission-denied", "Candidate profile not found or unauthorized.");
      }

      // 3. Payload and Input Validation
      const data = request.data;
      if (!data) {
        throw new HttpsError("invalid-argument", "Missing request payload.");
      }

      const { currentSkills } = data;

      if (!currentSkills || !Array.isArray(currentSkills) || currentSkills.length === 0) {
        return { relatedSkills: [] };
      }

      const cleanedSkills = currentSkills
        .filter((s: any) => typeof s === "string" && s.trim().length > 0)
        .map((s: string) => s.trim())
        .slice(0, 50);

      if (cleanedSkills.length === 0) {
        return { relatedSkills: [] };
      }

      // 4. Secure API Key Retrieval
      const apiKey = (process.env.GEMINI_API_KEY || "").trim();
      if (!apiKey) {
        console.error("GEMINI_API_KEY secret is not configured on the backend.");
        throw new HttpsError("failed-precondition", "AI service is currently misconfigured.");
      }

      // 5. Model Selection
      const model = process.env.GEMINI_MODEL || "gemini-3.6-flash";

      const prompt = `Given the following list of technical skills: ${cleanedSkills.join(", ")}.
Suggest 5 related technical skills that this candidate would benefit from learning or might already know.

The output must be a valid JSON array of strings.
Example: ["Skill A", "Skill B", "Skill C"]
Do not include any markdown formatting.`;

      // 6. Invoke Gemini REST API
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
              temperature: 0.7,
              responseMimeType: "application/json",
            },
          }),
        }
      );

      if (!response.ok) {
        const errText = await response.text().catch(() => "");
        console.error(`Gemini API returned status ${response.status}: ${errText}`);
        return { relatedSkills: [] };
      }

      const responseData: any = await response.json();
      const responseText = responseData?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!responseText || typeof responseText !== "string") {
        return { relatedSkills: [] };
      }

      // 7. Parse and Filter Response
      let cleanJson = responseText.trim();
      if (cleanJson.startsWith("```")) {
        cleanJson = cleanJson
          .replace(/^```json\s*/i, "")
          .replace(/^```\s*/, "")
          .replace(/```$/, "")
          .trim();
      }

      let parsedSkills: any[];
      try {
        parsedSkills = JSON.parse(cleanJson);
      } catch (e: any) {
        console.error("Failed to parse related skills JSON:", e);
        return { relatedSkills: [] };
      }

      if (!Array.isArray(parsedSkills)) {
        return { relatedSkills: [] };
      }

      const lowerExisting = new Set(cleanedSkills.map((s: string) => s.toLowerCase()));
      const relatedSkills = parsedSkills
        .map((s: any) => String(s).trim())
        .filter((s: string) => s.length > 0 && !lowerExisting.has(s.toLowerCase()))
        .slice(0, 5);

      return {
        relatedSkills,
      };
    } catch (error: any) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Unhandled error in getRelatedSkills:", error);
      return { relatedSkills: [] };
    }
  }
);

export const deleteUserAccount = onCall(
  { region: "us-central1" },
  async (request) => {
    // 1. Strict Authentication Check
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "You must be signed in to delete your account.");
    }

    const userId = request.auth.uid;
    console.log(`[deleteUserAccount] Initiating permanent deletion for UID: ${userId}`);

    try {
      // 2. Fetch recruiter profile to inspect company and personal assets
      const recruiterRef = db.collection("recruiters").doc(userId);
      const recruiterDoc = await recruiterRef.get();
      const recruiterData = recruiterDoc.exists ? recruiterDoc.data() : null;
      const companyId = recruiterData?.companyId;
      const recruiterPhotoUrl = recruiterData?.photoUrl;

      // 3. Handle Company Data with ownership safety
      if (companyId) {
        const companyRef = db.collection("companies").doc(companyId);
        const companyDoc = await companyRef.get();
        if (companyDoc.exists) {
          const companyData = companyDoc.data();
          const createdBy = companyData?.meta?.createdBy;

          // Check if other active recruiters belong to this company
          const otherRecruiters = await db
            .collection("recruiters")
            .where("companyId", "==", companyId)
            .get();

          const hasOtherRecruiters = otherRecruiters.docs.some(
            (doc) => doc.id !== userId
          );

          if (!hasOtherRecruiters && (createdBy === userId || !createdBy)) {
            // Delete company logo from Storage if hosted in bucket
            const logoUrl =
              companyData?.profile?.logoUrl || companyData?.logoUrl;
            if (logoUrl && typeof logoUrl === "string") {
              try {
                const bucket = admin.storage().bucket();
                const matches = logoUrl.match(/\/o\/([^?]+)/);
                if (matches && matches[1]) {
                  const decodedPath = decodeURIComponent(matches[1]);
                  await bucket
                    .file(decodedPath)
                    .delete()
                    .catch((e: any) => {
                      console.warn(
                        `[deleteUserAccount] Storage delete company logo warning: ${e.message}`
                      );
                    });
                }
              } catch (storageErr: any) {
                console.warn(
                  `[deleteUserAccount] Could not delete company logo from storage: ${storageErr.message}`
                );
              }
            }
            // Delete the company document
            await companyRef.delete();
            console.log(`[deleteUserAccount] Deleted company document: ${companyId}`);
          }
        }
      }

      // 4. Handle recruiter profile photo in Firebase Storage if any
      if (recruiterPhotoUrl && typeof recruiterPhotoUrl === "string") {
        try {
          const bucket = admin.storage().bucket();
          const matches = recruiterPhotoUrl.match(/\/o\/([^?]+)/);
          if (matches && matches[1]) {
            const decodedPath = decodeURIComponent(matches[1]);
            await bucket
              .file(decodedPath)
              .delete()
              .catch((e: any) => {
                console.warn(
                  `[deleteUserAccount] Storage delete recruiter photo warning: ${e.message}`
                );
              });
          }
        } catch (storageErr: any) {
          console.warn(
            `[deleteUserAccount] Could not delete recruiter photo from storage: ${storageErr.message}`
          );
        }
      }

      const batchSize = 400;
      let batch = db.batch();
      let opCount = 0;

      // 5. Delete recruiter notifications (notification_recruter)
      const notifQuery = await db
        .collection("notification_recruter")
        .where("recruiterId", "==", userId)
        .get();

      for (const doc of notifQuery.docs) {
        batch.delete(doc.ref);
        opCount++;
        if (opCount >= batchSize) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }
      console.log(`[deleteUserAccount] Deleted ${notifQuery.docs.length} recruiter notifications`);

      // 6. Handle Jobs & Applications posted by this recruiter
      const jobsQuery = await db
        .collection("jobs")
        .where("recruiterId", "==", userId)
        .get();

      for (const jobDoc of jobsQuery.docs) {
        const jobId = jobDoc.id;

        // Clean up applications for this job
        const appsQuery = await db
          .collection("job_applications")
          .where("jobId", "==", jobId)
          .get();

        for (const appDoc of appsQuery.docs) {
          batch.delete(appDoc.ref);
          opCount++;
          if (opCount >= batchSize) {
            await batch.commit();
            batch = db.batch();
            opCount = 0;
          }
        }

        // Delete the job doc
        batch.delete(jobDoc.ref);
        opCount++;
        if (opCount >= batchSize) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }
      console.log(`[deleteUserAccount] Deleted ${jobsQuery.docs.length} jobs created by recruiter`);

      // 7. Handle Chats & Messages
      const chatsQuery = await db
        .collection("chats")
        .where("recruiterId", "==", userId)
        .get();

      for (const chatDoc of chatsQuery.docs) {
        // Delete messages in subcollection
        const messagesQuery = await chatDoc.ref.collection("messages").get();
        for (const msgDoc of messagesQuery.docs) {
          batch.delete(msgDoc.ref);
          opCount++;
          if (opCount >= batchSize) {
            await batch.commit();
            batch = db.batch();
            opCount = 0;
          }
        }
        // Delete the chat document
        batch.delete(chatDoc.ref);
        opCount++;
        if (opCount >= batchSize) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }
      console.log(`[deleteUserAccount] Deleted ${chatsQuery.docs.length} chat threads`);

      // 8. Delete user role doc and recruiter profile doc
      const userDocRef = db.collection("users").doc(userId);
      batch.delete(userDocRef);
      batch.delete(recruiterRef);
      opCount += 2;

      if (opCount > 0) {
        await batch.commit();
      }
      console.log(`[deleteUserAccount] Deleted users/${userId} and recruiters/${userId}`);

      // 9. Delete Firebase Auth User Record
      try {
        await admin.auth().deleteUser(userId);
        console.log(`[deleteUserAccount] Successfully deleted Firebase Auth user: ${userId}`);
      } catch (authErr: any) {
        if (authErr.code !== "auth/user-not-found") {
          console.error(`[deleteUserAccount] Error deleting Firebase Auth user:`, authErr);
          throw new HttpsError("internal", "Failed to delete authentication user record.");
        }
      }

      return {
        success: true,
        message: "User account and associated recruiter data permanently deleted.",
      };
    } catch (error: any) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("[deleteUserAccount] Unhandled error:", error);
      throw new HttpsError("internal", "An error occurred while deleting your account. Please try again.");
    }
  }
);



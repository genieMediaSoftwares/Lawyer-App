const ApiResponse = require("../../config/ApiResponse");
const AiConversation = require("../../models/AiConversation");

function generateTitle(message) {
  if (!message) return "New Legal Conversation";
  let title = message.trim().split("\n")[0];
  title = title.replace(/[#*`_~]/g, "").trim();
  if (title.length > 35) {
    title = title.substring(0, 35) + "...";
  }
  return title || "New Legal Conversation";
}

class AiController {
  /**
   * GET /api/ai/conversations
   * Fetch all active conversations for the logged-in user sorted by most recent
   */
  async getConversations(req, res, next) {
    try {
      const userId = req.user._id;
      const conversations = await AiConversation.find({ userId, status: "active" })
        .sort({ updatedAt: -1 })
        .select("_id title messages createdAt updatedAt");

      const formatted = conversations.map((c) => {
        const lastMsg = c.messages[c.messages.length - 1];
        return {
          id: c._id.toString(),
          title: c.title,
          lastMessage: lastMsg ? lastMsg.text : "",
          createdAt: c.createdAt,
          updatedAt: c.updatedAt,
          messageCount: c.messages.length,
        };
      });

      return ApiResponse.success(res, "Conversations retrieved successfully.", {
        conversations: formatted,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/ai/conversations/:id
   * Fetch a single conversation with full message history
   */
  async getConversationById(req, res, next) {
    try {
      const { id } = req.params;
      const userId = req.user._id;

      const conversation = await AiConversation.findOne({ _id: id, userId });
      if (!conversation) {
        return ApiResponse.error(res, "Conversation not found.", 404);
      }

      return ApiResponse.success(res, "Conversation retrieved successfully.", {
        conversation: {
          id: conversation._id.toString(),
          title: conversation.title,
          status: conversation.status,
          messages: conversation.messages,
          createdAt: conversation.createdAt,
          updatedAt: conversation.updatedAt,
        },
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/ai/conversations
   * Start a new conversation explicitly
   */
  async createConversation(req, res, next) {
    try {
      const userId = req.user._id;
      const { title } = req.body;

      const conversation = await AiConversation.create({
        userId,
        title: title || "New Legal Conversation",
        messages: [],
      });

      return ApiResponse.success(res, "Conversation created successfully.", {
        conversation: {
          id: conversation._id.toString(),
          title: conversation.title,
          messages: conversation.messages,
          createdAt: conversation.createdAt,
          updatedAt: conversation.updatedAt,
        },
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * DELETE /api/ai/conversations/:id
   * Delete a single conversation owned by logged-in user
   */
  async deleteConversation(req, res, next) {
    try {
      const { id } = req.params;
      const userId = req.user._id;

      const conversation = await AiConversation.findOneAndDelete({ _id: id, userId });
      if (!conversation) {
        return ApiResponse.error(res, "Conversation not found.", 404);
      }

      return ApiResponse.success(res, "Conversation deleted successfully.", { id });
    } catch (error) {
      next(error);
    }
  }

  /**
   * DELETE /api/ai/conversations
   * Delete all conversations for logged-in user
   */
  async deleteAllConversations(req, res, next) {
    try {
      const userId = req.user._id;
      await AiConversation.deleteMany({ userId });

      return ApiResponse.success(res, "All conversations deleted successfully.");
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/ai/chat
   * Chat endpoint with persistent conversation history context
   */
  async chat(req, res, next) {
    try {
      const { message, conversationId, history } = req.body;
      const userId = req.user._id;

      if (!message || typeof message !== "string" || !message.trim()) {
        return ApiResponse.error(res, "Message is required.", 400);
      }

      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey || apiKey === "your_gemini_api_key_here") {
        return ApiResponse.error(
          res,
          "Gemini API key is not configured. Please add it to your environment variables.",
          500
        );
      }

      let conversation = null;

      if (conversationId) {
        conversation = await AiConversation.findOne({ _id: conversationId, userId });
        if (!conversation) {
          return ApiResponse.error(res, "Conversation not found.", 404);
        }
      } else {
        // Create a new conversation with auto-generated title
        conversation = new AiConversation({
          userId,
          title: generateTitle(message),
          messages: [],
        });
      }

      // Add the user message to DB conversation record
      conversation.messages.push({
        role: "user",
        text: message.trim(),
        timestamp: new Date(),
      });

      // Prepare context contents for Gemini API from stored conversation messages
      const contents = [];
      for (const msg of conversation.messages) {
        contents.push({
          role: msg.role === "model" || msg.role === "assistant" ? "model" : "user",
          parts: [{ text: msg.text }],
        });
      }

      // System instruction defines GenieLaw AI's persona, rules, response structure, and jurisdiction
      const systemInstruction = {
        parts: [
          {
            text: `You are "GenieLaw AI", an intelligent AI Legal Assistant integrated into a Lawyer Consultation Application for users in India.

Your role is to provide accurate, easy-to-understand, and informative legal guidance based on Indian laws. You are NOT a lawyer and you do NOT provide official legal advice, legal representation, or guarantees regarding legal outcomes.

Your primary objective is to help users understand legal concepts, explain legal procedures, suggest next steps, list commonly required documents, and encourage users to consult a qualified lawyer whenever personalized legal assistance is required.

==========================================================
YOUR RESPONSIBILITIES
==========================================================

You should:
• Answer legal questions clearly and professionally.
• Explain Indian legal procedures in simple language.
• Guide users on possible legal options.
• Suggest commonly required documents.
• Explain legal terminology.
• Help users understand legal notices, agreements, contracts, complaints, FIRs, divorce procedures, property matters, labour disputes, consumer complaints, cybercrime, and other common legal topics.
• Ask follow-up questions whenever additional information is needed.
• Keep answers concise but informative.
• Be polite, empathetic, and professional.

==========================================================
RESPONSE STYLE
==========================================================

Every response should follow this style whenever applicable:

### Overview
Briefly explain the legal issue.

### What You Can Do
Provide practical steps.

### Documents Required
List important documents if applicable.

### Important Note
Mention important legal precautions.

### Need Legal Help?
If you need personalized legal advice, you can post your case in this app and connect with a verified lawyer.

==========================================================
IMPORTANT RULES
==========================================================

Never:
• Pretend to be an advocate.
• Claim that a user will definitely win a case.
• Predict court judgments.
• Draft legally binding documents as final versions.
• Encourage illegal activities.
• Mislead users.
• Fabricate laws or court decisions.

Always:
• Mention that legal outcomes depend on individual facts.
• Recommend consulting a qualified lawyer whenever necessary.
• Explain that your responses are informational.

==========================================================
LEGAL JURISDICTION
==========================================================

Always answer according to Indian law unless the user explicitly asks about another country's legal system.

==========================================================
FOLLOW-UP QUESTIONS
==========================================================

If the user's question lacks sufficient information, ask relevant follow-up questions before giving a detailed answer.

Examples:
- "What type of property is involved?"
- "Is there a written agreement?"
- "Which state in India are you located in?"
- "When did this incident occur?"

==========================================================
PREDEFINED KNOWLEDGE (Frequently Asked Legal Topics)
==========================================================

You should naturally answer questions related to the following topics:

1. Recovery of Borrowed Money:
Guide users to collect evidence, communicate with the borrower, send a legal notice if necessary, and explain that a civil recovery suit may be an option.

2. Filing a Police Complaint:
Explain how to visit the police station, submit a complaint, preserve evidence, obtain an acknowledgement, and seek legal assistance for serious offences.

3. Property Purchase and Sale:
Explain common documents including Sale Deed, Title Documents, Encumbrance Certificate, Identity Proof, Tax Receipts, Registration Documents, and ownership verification.

4. Receiving a Legal Notice:
Advise users not to ignore the notice, read it carefully, collect relevant documents, and consult a lawyer before responding.

5. Divorce Procedure:
Explain the general process including consultation, petition filing, court hearings, mediation (where applicable), and final decree.

6. Salary Not Paid by Employer:
Suggest communicating with HR, maintaining employment records, sending a written request, and consulting a labour lawyer if required.

7. Rental Agreement:
Explain common clauses such as rent amount, security deposit, duration, maintenance responsibilities, landlord and tenant details, and registration where applicable.

8. Road Accident:
Explain immediate safety measures, police reporting, medical assistance, insurance notification, evidence collection, and legal consultation if required.

9. Legal Document Review:
Inform users that they can upload agreements, notices, contracts, property documents, or court papers for a general explanation, while clarifying that only a lawyer can provide legal advice.

10. Connecting with a Lawyer:
Explain that users can post a legal case, upload supporting documents, receive lawyer recommendations, chat with lawyers, schedule consultations, and track their cases through the application.

==========================================================
SUPPORTED LEGAL TOPICS
==========================================================

You should confidently answer general questions related to:
Family Law, Property Law, Criminal Law, Civil Law, Consumer Protection, Employment & Labour Law, Cyber Law, Motor Vehicle Accidents, Rental & Tenancy, Contracts, Cheque Bounce, Legal Notices, Documentation, Police Complaints, Consumer Complaints, Succession, Inheritance, Domestic Violence, Maintenance, Marriage, Divorce, Child Custody, Land Disputes, Employment Issues, Intellectual Property (basic guidance), Constitutional Rights (general explanation).

==========================================================
WHEN USERS ASK NON-LEGAL QUESTIONS
==========================================================

If the user asks something unrelated to law, politely explain that you are an AI Legal Assistant specialized in legal guidance and encourage them to ask legal questions.

Example:
"I am designed to assist with legal information and legal procedures. Please ask any legal question, and I'll be happy to help."

==========================================================
ENDING EVERY LEGAL RESPONSE
==========================================================

Whenever appropriate, conclude with:
"If you need personalized legal advice or representation, you can post your case in this app and connect with a verified lawyer."

==========================================================
DISCLAIMER
==========================================================

Responses are provided for informational purposes only and should not be considered professional legal advice. Laws may vary based on the facts of each case and jurisdiction. For legal representation or case-specific advice, consult a qualified advocate.`
          }
        ]
      };

      const candidateModels = [
        "gemini-flash-latest",
        "gemini-3.5-flash",
        "gemma-4-26b-a4b-it",
        "gemma-4-31b-it",
        "gemini-3-flash-preview",
        "gemini-2.0-flash"
      ];

      let aiText = null;
      let lastErrorText = "";

      for (const model of candidateModels) {
        try {
          const response = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json"
              },
              body: JSON.stringify({
                contents,
                systemInstruction
              })
            }
          );

          if (response.ok) {
            const responseData = await response.json();
            aiText = responseData.candidates?.[0]?.content?.parts?.[0]?.text;
            if (aiText) {
              break;
            }
          } else {
            lastErrorText = await response.text();
            console.warn(`Gemini API Model [${model}] returned status ${response.status}`);
          }
        } catch (err) {
          console.error(`Error requesting model [${model}]:`, err.message);
          lastErrorText = err.message;
        }
      }

      if (!aiText) {
        return ApiResponse.error(res, `Failed to communicate with Gemini API: ${lastErrorText}`, 502);
      }

      // Add AI model response to DB conversation record
      conversation.messages.push({
        role: "model",
        text: aiText,
        timestamp: new Date(),
      });

      await conversation.save();

      return ApiResponse.success(res, "Chat completed successfully.", {
        response: aiText,
        conversationId: conversation._id.toString(),
        title: conversation.title,
        messages: conversation.messages,
      });
    } catch (error) {
      next(error);
    }
  }

  async transcribe(req, res, next) {
    try {
      if (!req.file) {
        return ApiResponse.error(res, "No audio file uploaded.", 400);
      }

      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey || apiKey === "your_gemini_api_key_here") {
        return ApiResponse.error(
          res,
          "Gemini API key is not configured. Please add it to your environment variables.",
          500
        );
      }

      const fs = require("fs");
      const audioBuffer = fs.readFileSync(req.file.path);
      const audioBase64 = audioBuffer.toString("base64");
      
      let mimeType = req.file.mimetype;
      if (mimeType === "application/octet-stream" || !mimeType) {
        mimeType = "audio/mp4";
      }

      const candidateModels = [
        "gemini-flash-latest",
        "gemini-3.5-flash",
        "gemini-2.0-flash"
      ];

      let aiText = null;
      let lastErrorText = "";

      for (const model of candidateModels) {
        try {
          const response = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json"
              },
              body: JSON.stringify({
                contents: [
                  {
                    role: "user",
                    parts: [
                      {
                        inlineData: {
                          mimeType: mimeType,
                          data: audioBase64
                        }
                      },
                      {
                        text: "Transcribe the following audio recording of a legal case description. " +
                              "Automatically detect the spoken language. If the language is English, generate an English transcript. " +
                              "If the language is Hindi, Telugu, or a mixture of Hindi/Telugu/English, automatically translate/transcribe it into a single natural English transcript, preserving the original legal meaning and context. " +
                              "Provide only the plain English transcription, keeping punctuation and formatting intact, without any introductory or concluding text, explanations, or metadata."
                      }
                    ]
                  }
                ]
              })
            }
          );

          if (response.ok) {
            const responseData = await response.json();
            aiText = responseData.candidates?.[0]?.content?.parts?.[0]?.text;
            if (aiText) {
              break;
            }
          } else {
            lastErrorText = await response.text();
            console.warn(`Gemini Transcribe API Model [${model}] returned status ${response.status}`);
          }
        } catch (err) {
          console.error(`Error transcribing with model [${model}]:`, err.message);
          lastErrorText = err.message;
        }
      }

      try {
        fs.unlinkSync(req.file.path);
      } catch (err) {
        console.error("Failed to delete temp file:", err);
      }

      if (!aiText) {
        return ApiResponse.error(res, `Failed to communicate with Gemini API: ${lastErrorText}`, 502);
      }

      return ApiResponse.success(res, "Audio transcribed successfully.", { transcript: aiText.trim() });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AiController();

const ApiResponse = require("../../config/ApiResponse");

class AiController {
  async chat(req, res, next) {
    try {
      const { message, history } = req.body;

      if (!message) {
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

      // Format conversation history for Gemini API
      // Gemini expects format: { role: "user" | "model", parts: [{ text: "..." }] }
      const contents = [];

      if (Array.isArray(history)) {
        for (const turn of history) {
          if (turn.role && turn.parts && Array.isArray(turn.parts) && turn.parts[0]?.text) {
            contents.push({
              role: turn.role === "model" ? "model" : "user",
              parts: [{ text: turn.parts[0].text }]
            });
          }
        }
      }

      // Add the latest user message
      contents.push({
        role: "user",
        parts: [{ text: message }]
      });

      // System instruction defines the AI's persona and rules
      const systemInstruction = {
        parts: [
          {
            text: "You are the GenieLaw AI Legal Assistant, an intelligent, helpful, and professional AI companion specializing in Indian law (including Criminal Law, Civil Cases, Property Disputes, Divorce & Family Law, GST & Taxation, and Consumer Rights). " +
                  "Format your responses in clean, structured Markdown, utilizing headers (###), bullet points, and blockquotes for tips or warnings where appropriate. " +
                  "Make your tone professional and authoritative yet accessible to a layperson. " +
                  "Always end your answers with a polite, standard disclaimer stating that your responses are for informational and educational support, and do not constitute formal legal counsel."
          }
        ]
      };

      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
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

      if (!response.ok) {
        const errorText = await response.text();
        console.error("Gemini API Error:", errorText);
        return ApiResponse.error(res, `Failed to communicate with Gemini API: ${response.statusText}`, response.status);
      }

      const responseData = await response.json();
      const aiText = responseData.candidates?.[0]?.content?.parts?.[0]?.text;

      if (!aiText) {
        return ApiResponse.error(res, "Invalid or empty response from Gemini API.", 502);
      }

      return ApiResponse.success(res, "Chat completed successfully.", { response: aiText });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AiController();

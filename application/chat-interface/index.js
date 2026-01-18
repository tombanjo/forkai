const express = require('express');
const cors = require('cors');
const { VertexAI } = require('@google-cloud/vertexai');
const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const app = express();
const port = process.env.PORT || 8080;

const modelName = process.env.MODEL_NAME || 'gemini-2.0-flash-lite';
const project = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCP_PROJECT;
const location = process.env.GOOGLE_CLOUD_REGION || process.env.GCP_REGION || 'us-central1';
const MODEL_PROVIDERS = Object.freeze({
  GOOGLE_VERTEXAI: 'google-vertexai',
  GOOGLE_AI_STUDIO: 'google-ai-studio',
});
const modelProvider = process.env.MODEL_PROVIDER || MODEL_PROVIDERS.GOOGLE_AI_STUDIO;
const googleAIStudioApiSecret = process.env.GOOGLE_AI_STUDIO_API_SECRET || 'gemini-api-key-secret';

class ModelProvider {
  async init() {
    throw new Error('Not implemented');
  }

  async generateContent(_userMessage) {
    throw new Error('Not implemented');
  }
}

class VertexAIProvider extends ModelProvider {
  constructor({ modelName, project, location }) {
    super();
    this.modelName = modelName;
    this.project = project;
    this.location = location;
    this.model = null;
  }

  async init() {
    if (!this.project) {
      throw new Error('GOOGLE_CLOUD_PROJECT environment variable is required for Vertex AI');
    }

    const vertexAI = new VertexAI({ project: this.project, location: this.location });
    this.model = vertexAI.getGenerativeModel({ model: this.modelName });
  }

  async generateContent(userMessage) {
    const result = await this.model.generateContent({
      contents: [{ role: 'user', parts: [{ text: userMessage }] }],
    });
    const response = result.response;
    return response.candidates[0].content.parts[0].text;
  }
}

class GoogleAIStudioProvider extends ModelProvider {
  constructor({ modelName, project, secretName }) {
    super();
    this.modelName = modelName;
    this.project = project;
    this.secretName = secretName;
    this.model = null;
  }

  async init() {
    if (!this.secretName) {
      throw new Error('GOOGLE_AI_STUDIO_API_SECRET environment variable is required for Google AI Studio');
    }

    if (!this.project && !this.secretName.startsWith('projects/')) {
      throw new Error('GOOGLE_CLOUD_PROJECT environment variable is required to resolve Secret Manager secrets');
    }

    const client = new SecretManagerServiceClient();
    const secretVersion = this.secretName.startsWith('projects/')
      ? `${this.secretName}/versions/latest`
      : `projects/${this.project}/secrets/${this.secretName}/versions/latest`;
    const [version] = await client.accessSecretVersion({ name: secretVersion });
    const apiKey = version.payload.data.toString('utf8').trim();

    const genAI = new GoogleGenerativeAI(apiKey);
    this.model = genAI.getGenerativeModel({ model: this.modelName });
  }

  async generateContent(userMessage) {
    const result = await this.model.generateContent(userMessage);
    const response = result.response;
    return response.text();
  }
}

const createProvider = () => {
  if (modelProvider === MODEL_PROVIDERS.GOOGLE_VERTEXAI) {
    console.log(`Using Vertex AI with model: ${modelName} (service account authentication)`);
    return new VertexAIProvider({ modelName, project, location });
  }

  if (modelProvider === MODEL_PROVIDERS.GOOGLE_AI_STUDIO) {
    console.log(`Using Google AI Studio with model: ${modelName} (API key authentication)`);
    return new GoogleAIStudioProvider({
      modelName,
      project,
      secretName: googleAIStudioApiSecret,
    });
  }

  throw new Error(`Invalid model provider: ${modelProvider}`);
};

const provider = createProvider();

// Configure CORS
const corsOptions = {
  origin: process.env.CORS_ALLOWED_ORIGIN || '*', // Default to allow all origins if not set
};
app.use(cors(corsOptions));

// Middleware to parse JSON payloads
app.use(express.json());

app.get('/', async (req, res) => {
  res.status(200).json({ message: 'Health check successful', request: req.body });
});

app.post('/', async (req, res) => {
  try {
    const jsonPayload = req.body;
    const userMessage = jsonPayload.message;

    if (!userMessage || !userMessage.trim()) {
      return res.status(400).json({ error: 'Message is required' });
    }

    const responseText = await provider.generateContent(userMessage);

    res.status(200).json({ 
      reply: responseText, 
      request: jsonPayload,
      debug: {
        MODEL_NAME: modelName,
        project: project,
        location: location,
        modelProvider: modelProvider,
      }
    });
  } catch (error) {
    console.error('Error generating content:', error);
    res.status(500).json({ 
      error: 'Error generating content',
      details: error.message 
    });
  }
});

const startServer = async () => {
  try {
    await provider.init();
  } catch (error) {
    console.error('Error: Failed to initialize model provider:', error);
    process.exit(1);
  }

  app.listen(port, '0.0.0.0', () => {
    console.log(`Server is running on http://0.0.0.0:${port}`);
  });
};

startServer();

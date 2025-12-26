import express from 'express';
import bodyParser from 'body-parser';
import pg from 'pg';
import client from 'prom-client';
import winston from 'winston';
import helmet from 'helmet';
import cors from 'cors';

const PORT = process.env.PORT || 5000;
const app = express();

// ----------------- Security & CORS -----------------
app.use(helmet());
app.use(cors());

// ----------------- Logging Setup -----------------
const { combine, timestamp, json } = winston.format;

const logger = winston.createLogger({
  level: 'info',
  format: combine(timestamp(), json()),
  transports: [
    new winston.transports.File({ filename: '/var/log/quiz/quiz.log' }),
    new winston.transports.Console()
  ]
});

// Middleware to log every request
app.use((req, res, next) => {
  logger.info({ message: 'Incoming request', method: req.method, path: req.url });
  next();
});

// ----------------- Database -----------------
const db = new pg.Client({
  user: process.env.DB_USER || 'quizuser',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'quizdb',
  password: process.env.DB_PASSWORD || 'quizpass223',
  port: process.env.DB_PORT || 5432
});

db.connect(err => {
  if (err) {
    logger.error({ message: 'Database connection failed', error: err.stack });
  } else {
    logger.info({ message: 'Connected to PostgreSQL' });
  }
});

// Load quizzes into memory
let quizzes = [];
async function loadQuizzes() {
  try {
    const res = await db.query('SELECT * FROM quiz');
    quizzes = res.rows;
    logger.info({ message: `Loaded ${quizzes.length} quizzes from database` });
  } catch (err) {
    logger.error({ message: 'Error loading quizzes', error: err.stack });
  }
}
loadQuizzes();

// ----------------- Prometheus Metrics -----------------
client.collectDefaultMetrics({ timeout: 5000 });

const totalCorrectGauge = new client.Gauge({
  name: 'quiz_total_correct',
  help: 'Total correct answers per session'
});

// /metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

// ----------------- Express Setup -----------------
app.use(express.static('public'));
app.use(bodyParser.urlencoded({ extended: true }));
app.set('view engine', 'ejs');

let currentQuestion = {};
let totalCorrect = 0;

// ----------------- Routes -----------------
app.get('/', async (req, res) => {
  totalCorrect = 0;
  await nextQuestion();
  logger.info({ message: 'New quiz session started' });
  res.render('index', { question: currentQuestion });
});

app.post('/quiz', async (req, res) => {
  const answer = req.body.answer.trim();
  let isCorrect = false;

  if (currentQuestion.answers.toLowerCase() === answer.toLowerCase()) {
    totalCorrect++;
    isCorrect = true;
    totalCorrectGauge.set(totalCorrect);
  }

  logger.info({
    message: 'Question answered',
    question: currentQuestion.questions,
    correct: isCorrect,
    totalScore: totalCorrect
  });

  await nextQuestion();
  res.render('index', {
    question: currentQuestion,
    wasCorrect: isCorrect,
    totalScore: totalCorrect
  });
});

app.get('/result', (req, res) => {
  res.render('result', { score: totalCorrect });
});

app.get('/history', (req, res) => {
  res.render('history', { quizzes: quizzes });
});

// ----------------- Helper Functions -----------------
async function nextQuestion() {
  if (quizzes.length === 0) {
    currentQuestion = { questions: 'No quizzes available', answers: '' };
    return;
  }
  currentQuestion = quizzes[Math.floor(Math.random() * quizzes.length)];
}

// ----------------- Global Error Handling -----------------
app.use((err, req, res, next) => {
  logger.error({ message: err.message, stack: err.stack });
  res.status(500).json({ error: 'Internal Server Error' });
});

// ----------------- Start Server -----------------
app.listen(PORT, () => {
  logger.info({ message: `Server running on http://localhost:${PORT}` });
});

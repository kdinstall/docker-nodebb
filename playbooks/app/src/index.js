import express from 'express';

const app = express();
const PORT = 3000;

// Middleware
app.use(express.json());

// ルート
app.get('/', (req, res) => {
  res.json({
    message: 'Express Sample Application',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      hello: '/hello{/:name}',
      echo: 'POST /echo'
    }
  });
});

// ヘルスチェック
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Hello エンドポイント
app.get('/hello{/:name}', (req, res) => {
  const name = req.params.name || 'World';
  res.json({
    message: `Hello, ${name}!`,
    timestamp: new Date().toISOString()
  });
});

// Echo エンドポイント
app.post('/echo', (req, res) => {
  res.json({
    received: req.body,
    timestamp: new Date().toISOString()
  });
});

// 404 ハンドラー
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Cannot ${req.method} ${req.path}`,
    availableEndpoints: ['/', '/health', '/hello{/:name}', 'POST /echo']
  });
});

// エラーハンドリングミドルウェア
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message
  });
});

// サーバー起動
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

// グレースフルシャットダウン
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT signal received: closing HTTP server');
  process.exit(0);
});

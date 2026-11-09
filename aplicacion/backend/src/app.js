const express = require('express');
const os = require('os');

const VERSION = process.env.APP_VERSION || 'dev';
const CORS_ORIGIN = process.env.CORS_ORIGIN || '';

function crearApp() {
  const app = express();
  app.use(express.json());

  // CORS solo para desarrollo local (en AWS el ALB sirve front y API en el mismo origen)
  if (CORS_ORIGIN) {
    app.use((req, res, next) => {
      res.set('Access-Control-Allow-Origin', CORS_ORIGIN);
      res.set('Access-Control-Allow-Headers', 'Content-Type');
      res.set('Access-Control-Allow-Methods', 'GET,POST,DELETE,OPTIONS');
      if (req.method === 'OPTIONS') return res.sendStatus(204);
      next();
    });
  }

  // Almacenamiento en memoria (suficiente para la demo; se reinicia con cada despliegue)
  let siguienteId = 3;
  const tareas = [
    { id: 1, titulo: 'Aprovisionar infraestructura con Terraform', hecha: true },
    { id: 2, titulo: 'Publicar imágenes en ECR', hecha: false },
  ];

  app.get('/api/health', (req, res) => {
    res.json({ estado: 'ok', version: VERSION });
  });

  app.get('/api/info', (req, res) => {
    res.json({
      servicio: 'backend',
      version: VERSION,
      host: os.hostname(),
      hora: new Date().toISOString(),
    });
  });

  app.get('/api/tareas', (req, res) => res.json(tareas));

  app.post('/api/tareas', (req, res) => {
    const titulo = (req.body && typeof req.body.titulo === 'string') ? req.body.titulo.trim() : '';
    if (!titulo) return res.status(400).json({ error: 'El campo "titulo" es obligatorio' });
    if (titulo.length > 200) return res.status(400).json({ error: 'Máximo 200 caracteres' });
    const tarea = { id: siguienteId++, titulo, hecha: false };
    tareas.push(tarea);
    res.status(201).json(tarea);
  });

  app.post('/api/tareas/:id/toggle', (req, res) => {
    const tarea = tareas.find((t) => t.id === Number(req.params.id));
    if (!tarea) return res.status(404).json({ error: 'Tarea no encontrada' });
    tarea.hecha = !tarea.hecha;
    res.json(tarea);
  });

  app.delete('/api/tareas/:id', (req, res) => {
    const i = tareas.findIndex((t) => t.id === Number(req.params.id));
    if (i === -1) return res.status(404).json({ error: 'Tarea no encontrada' });
    tareas.splice(i, 1);
    res.sendStatus(204);
  });

  app.use('/api', (req, res) => res.status(404).json({ error: 'Ruta no encontrada' }));

  // Manejo centralizado de errores (JSON mal formado, etc.)
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    const status = err.status || 500;
    if (status >= 500) console.error(err);
    res.status(status).json({ error: status >= 500 ? 'Error interno' : err.message });
  });

  return app;
}

module.exports = { crearApp };

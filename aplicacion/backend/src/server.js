const { crearApp } = require('./app');

const PORT = Number(process.env.PORT) || 3000;
const server = crearApp().listen(PORT, () => {
  console.log(`Backend escuchando en el puerto ${PORT} (versión ${process.env.APP_VERSION || 'dev'})`);
});

// ECS envía SIGTERM al detener una tarea: cerramos conexiones de forma ordenada
process.on('SIGTERM', () => {
  console.log('SIGTERM recibido, cerrando servidor...');
  server.close(() => process.exit(0));
});

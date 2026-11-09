const { test, before, after } = require('node:test');
const assert = require('node:assert');
const { crearApp } = require('../src/app');

let server;
let base;

before(async () => {
  server = crearApp().listen(0);
  await new Promise((r) => server.once('listening', r));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

test('GET /api/health responde ok', async () => {
  const res = await fetch(`${base}/api/health`);
  assert.strictEqual(res.status, 200);
  assert.strictEqual((await res.json()).estado, 'ok');
});

test('POST /api/tareas crea una tarea', async () => {
  const res = await fetch(`${base}/api/tareas`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ titulo: 'Probar pipeline' }),
  });
  assert.strictEqual(res.status, 201);
  const tarea = await res.json();
  assert.strictEqual(tarea.titulo, 'Probar pipeline');

  const lista = await (await fetch(`${base}/api/tareas`)).json();
  assert.ok(lista.some((t) => t.id === tarea.id));
});

test('POST /api/tareas sin título devuelve 400', async () => {
  const res = await fetch(`${base}/api/tareas`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({}),
  });
  assert.strictEqual(res.status, 400);
});

test('DELETE de tarea inexistente devuelve 404', async () => {
  const res = await fetch(`${base}/api/tareas/9999`, { method: 'DELETE' });
  assert.strictEqual(res.status, 404);
});

const API = (window.API_BASE || '') + '/api';
const $ = (id) => document.getElementById(id);

async function api(ruta, opciones = {}) {
  const res = await fetch(API + ruta, {
    headers: { 'Content-Type': 'application/json' },
    ...opciones,
  });
  if (!res.ok && res.status !== 204) {
    const cuerpo = await res.json().catch(() => ({}));
    throw new Error(cuerpo.error || `Error HTTP ${res.status}`);
  }
  return res.status === 204 ? null : res.json();
}

function mostrarError(msg) {
  const el = $('error');
  el.textContent = msg;
  el.hidden = !msg;
}

async function cargarInfo() {
  try {
    const info = await api('/info');
    $('ver-back').textContent = info.version;
    $('host-back').textContent = info.host;
    $('salud').textContent = 'operativa';
    $('salud').className = 'pill ok';
  } catch (e) {
    $('salud').textContent = 'sin conexión';
    $('salud').className = 'pill mal';
  }
}

function render(tareas) {
  const ul = $('lista');
  ul.innerHTML = '';
  for (const t of tareas) {
    const li = document.createElement('li');
    if (t.hecha) li.classList.add('hecha');

    const chk = document.createElement('input');
    chk.type = 'checkbox';
    chk.checked = t.hecha;
    chk.onchange = () => accion(() => api(`/tareas/${t.id}/toggle`, { method: 'POST' }));

    const span = document.createElement('span');
    span.textContent = t.titulo; // textContent evita inyección de HTML

    const del = document.createElement('button');
    del.textContent = '✕';
    del.className = 'del';
    del.title = 'Eliminar';
    del.onclick = () => accion(() => api(`/tareas/${t.id}`, { method: 'DELETE' }));

    li.append(chk, span, del);
    ul.append(li);
  }
}

async function cargarTareas() {
  render(await api('/tareas'));
}

async function accion(fn) {
  try {
    mostrarError('');
    await fn();
    await cargarTareas();
  } catch (e) {
    mostrarError(e.message);
  }
}

$('form').addEventListener('submit', (ev) => {
  ev.preventDefault();
  const titulo = $('titulo').value;
  accion(async () => {
    await api('/tareas', { method: 'POST', body: JSON.stringify({ titulo }) });
    $('titulo').value = '';
  });
});

cargarInfo();
accion(() => Promise.resolve());

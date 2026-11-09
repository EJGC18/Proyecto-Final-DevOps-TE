# pipelines/ — Definiciones y scripts de los 3 pipelines

Herramienta: **GitHub Actions**. GitHub solo ejecuta workflows ubicados en `.github/workflows/`,
así que esa es la copia que se ejecuta; `pipelines/workflows/` contiene copias idénticas para la
carpeta compartida. Si editas un workflow, ejecuta `./pipelines/sincronizar.sh`.

| Pipeline | Definición | Disparador | Scripts |
|---|---|---|---|
| 1 · Infraestructura | `workflows/1-infraestructura.yml` | push a `main` en `terraform/**` (apply), PR (plan), manual (plan/apply/destroy) | — (Terraform) |
| 2 · Build + ECR | `workflows/2-build-publicacion.yml` | push a `main` en `aplicacion/**`, manual | `scripts/build-push.sh` |
| 3 · Despliegue ECS | `workflows/3-despliegue.yml` | al terminar con éxito el Pipeline 2, manual (cualquier tag) | `scripts/deploy-ecs.sh`, `scripts/smoke-test.sh` |

```
push a main ──► [2] pruebas ─► build backend ┐
                               build frontend ┴─► push ECR (tag = SHA) ──► [3] verificar ECR
                                                                             ─► deploy backend ─► deploy frontend
                                                                             ─► smoke test ALB ─► (rollback si falla)
```

## Manejo de errores

- **Pipeline 1:** `fmt -check` y `validate` antes del plan; el `apply` usa exactamente el plan revisado; bloqueo de estado en S3 (`use_lockfile`) y `concurrency` para que nunca haya dos `apply` simultáneos; `destroy` exige escribir `DESTRUIR`.
- **Pipeline 2:** si fallan las pruebas no se construye nada; si ECR no existe, espera y luego falla con mensaje claro.
- **Pipeline 3:** verifica que la imagen exista antes de tocar ECS; *deployment circuit breaker* de ECS con rollback automático; espera `services-stable`; si no se estabiliza o el smoke test falla, vuelve a la task definition anterior.

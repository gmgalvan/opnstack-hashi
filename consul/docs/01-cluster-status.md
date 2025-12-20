# 1. Verificar Estado del Cluster y Liderazgo

Ejecutar en cualquier servidor o cliente:

## Ver todos los nodos

```bash
consul members
```

## Ver cuál servidor es el líder

```bash
consul operator raft list-peers
```

---

[← Volver al índice](./README.md) | [Siguiente: Setup Client-1 →](./02-setup-client1-nginx.md)

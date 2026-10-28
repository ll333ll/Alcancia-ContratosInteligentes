# Alcancía — Smart Contract en Sui Move

Una **alcancía** (piggy bank) on-chain: un objeto compartido en el que
cualquiera puede depositar SUI hacia una meta de ahorro. Solo el dueño puede
retirar, y únicamente cuando la meta se ha alcanzado.

El contrato vive en [`alcancia/sources/alcancia.move`](alcancia/sources/alcancia.move).

## Cómo funciona

| Función | Quién | Qué hace |
|---|---|---|
| `crear(meta)` | cualquiera | Crea y comparte una alcancía con una meta (en MIST). La meta debe ser > 0. |
| `depositar(a, pago)` | cualquiera | Mete SUI en la alcancía. Rechaza depósitos de cero. Emite `Deposito`. |
| `retirar(a)` | solo dueño | Saca **todo**, solo si se alcanzó la meta. Emite `Retiro`. |
| `retirar_monto(a, monto)` | solo dueño | Retiro **parcial** tras alcanzar la meta. Emite `Retiro`. |

### Funciones de lectura

- `saldo(a)` — cuánto llevas ahorrado (MIST)
- `meta(a)` — la meta de ahorro (MIST)
- `dueno(a)` — dirección del dueño
- `meta_alcanzada(a)` — `true` si ya se llegó a la meta
- `progreso(a)` — porcentaje 0..=100 (se satura en 100)
- `faltante(a)` — cuánto falta para la meta (0 si ya se alcanzó)

### Códigos de error

| Código | Constante | Significado |
|---|---|---|
| 0 | `ENoEresDueno` | Solo el dueño puede retirar |
| 1 | `EMetaNoAlcanzada` | La meta aún no se ha alcanzado |
| 2 | `EDepositoCero` | No se puede depositar cero |
| 3 | `EMetaCero` | La meta debe ser mayor que cero |
| 4 | `EFondosInsuficientes` | Se intentó retirar más de lo disponible |

## Compilar y probar

```bash
cd alcancia
sui move build
sui move test            # 9 pruebas, 100% de cobertura del módulo
sui move test --coverage && sui move coverage summary
```

## Publicar

```bash
cd alcancia
sui client faucet                       # obtener gas en testnet
sui client publish --gas-budget 100000000
```

### Despliegue de referencia (testnet)

Este repositorio incluye una publicación real en **testnet** (ver
[`alcancia/Published.toml`](alcancia/Published.toml)):

- **Package ID:** `0xfa9006e2530c633fe4af977831a8a13182fdde8257080a8fab5e75ac3d1512b1`

Ejemplo de uso con PTB (depósito que alcanza una meta de 0.5 SUI):

```bash
PKG=0xfa9006e2530c633fe4af977831a8a13182fdde8257080a8fab5e75ac3d1512b1

# crear alcancía con meta de 0.5 SUI (500000000 MIST)
sui client call --package $PKG --module alcancia --function crear \
  --args 500000000 --gas-budget 100000000

# depositar 0.5 SUI dividiendo desde el gas
sui client ptb \
  --split-coins gas "[500000000]" --assign coin \
  --move-call $PKG::alcancia::depositar @<ALCANCIA_ID> coin.0 \
  --gas-budget 100000000

# retirar todo (solo dueño, meta alcanzada)
sui client call --package $PKG --module alcancia --function retirar \
  --args <ALCANCIA_ID> --gas-budget 100000000
```

## Mejoras sobre la versión original

- **Eventos** (`AlcanciaCreada`, `Deposito`, `Retiro`) para indexación off-chain.
- **Retiro parcial** (`retirar_monto`) para no tener que vaciar la alcancía.
- **Validaciones** nuevas: meta > 0, depósito > 0, no retirar más de lo disponible.
- **Funciones de lectura** nuevas: `meta`, `dueno`, `meta_alcanzada`, `progreso`, `faltante`.
- **Suite de pruebas completa** con `test_scenario` (camino feliz + todos los casos de fallo), 100% de cobertura del módulo.

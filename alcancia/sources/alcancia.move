/// Alcancía (piggy bank) on Sui.
///
/// Un objeto compartido en el que cualquiera puede depositar SUI hacia una meta
/// de ahorro. Solo el dueño puede retirar, y únicamente cuando la meta se ha
/// alcanzado. Emite eventos para poder indexar la actividad fuera de la cadena.
module alcancia::alcancia {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::event;

    // ---------------------------------------------------------------------
    // Códigos de error
    // ---------------------------------------------------------------------
    /// Solo el dueño puede ejecutar esta acción.
    const ENoEresDueno: u64 = 0;
    /// La meta de ahorro aún no se ha alcanzado.
    const EMetaNoAlcanzada: u64 = 1;
    /// No se puede depositar una cantidad de cero.
    const EDepositoCero: u64 = 2;
    /// La meta debe ser mayor que cero.
    const EMetaCero: u64 = 3;
    /// Se intentó retirar más de lo disponible.
    const EFondosInsuficientes: u64 = 4;

    // ---------------------------------------------------------------------
    // Estado
    // ---------------------------------------------------------------------
    /// La alcancía: quién es el dueño, cuánto quiere ahorrar y cuánto lleva.
    public struct Alcancia has key {
        id: UID,
        dueno: address,
        /// Meta en MIST (1 SUI = 1_000_000_000 MIST).
        meta: u64,
        ahorro: Balance<SUI>,
    }

    // ---------------------------------------------------------------------
    // Eventos
    // ---------------------------------------------------------------------
    public struct AlcanciaCreada has copy, drop {
        alcancia: ID,
        dueno: address,
        meta: u64,
    }

    public struct Deposito has copy, drop {
        alcancia: ID,
        de: address,
        monto: u64,
        nuevo_saldo: u64,
    }

    public struct Retiro has copy, drop {
        alcancia: ID,
        dueno: address,
        monto: u64,
        saldo_restante: u64,
    }

    // ---------------------------------------------------------------------
    // Escritura
    // ---------------------------------------------------------------------
    /// Crea una alcancía con una meta de ahorro y la comparte.
    public fun crear(meta: u64, ctx: &mut TxContext) {
        assert!(meta > 0, EMetaCero);
        let a = Alcancia {
            id: object::new(ctx),
            dueno: ctx.sender(),
            meta,
            ahorro: balance::zero(),
        };
        event::emit(AlcanciaCreada {
            alcancia: object::id(&a),
            dueno: a.dueno,
            meta,
        });
        transfer::share_object(a);
    }

    /// Cualquiera puede meter plata (tú, un familiar, un amigo...).
    public fun depositar(a: &mut Alcancia, pago: Coin<SUI>, ctx: &TxContext) {
        let monto = coin::value(&pago);
        assert!(monto > 0, EDepositoCero);
        balance::join(&mut a.ahorro, coin::into_balance(pago));
        event::emit(Deposito {
            alcancia: object::id(a),
            de: ctx.sender(),
            monto,
            nuevo_saldo: balance::value(&a.ahorro),
        });
    }

    /// Solo el dueño puede sacar todo, y solo si ya llegó a la meta.
    public fun retirar(a: &mut Alcancia, ctx: &mut TxContext) {
        let total = balance::value(&a.ahorro);
        retirar_monto(a, total, ctx);
    }

    /// Retiro parcial: el dueño saca `monto` una vez alcanzada la meta.
    /// Permite seguir ahorrando sin tener que vaciar la alcancía.
    public fun retirar_monto(a: &mut Alcancia, monto: u64, ctx: &mut TxContext) {
        assert!(ctx.sender() == a.dueno, ENoEresDueno);
        let total = balance::value(&a.ahorro);
        assert!(total >= a.meta, EMetaNoAlcanzada);
        assert!(monto <= total, EFondosInsuficientes);
        let plata = coin::take(&mut a.ahorro, monto, ctx);
        transfer::public_transfer(plata, a.dueno);
        event::emit(Retiro {
            alcancia: object::id(a),
            dueno: a.dueno,
            monto,
            saldo_restante: balance::value(&a.ahorro),
        });
    }

    // ---------------------------------------------------------------------
    // Lectura
    // ---------------------------------------------------------------------
    /// Ver cuánto llevas ahorrado (en MIST).
    public fun saldo(a: &Alcancia): u64 {
        balance::value(&a.ahorro)
    }

    /// La meta de ahorro (en MIST).
    public fun meta(a: &Alcancia): u64 {
        a.meta
    }

    /// Dirección del dueño.
    public fun dueno(a: &Alcancia): address {
        a.dueno
    }

    /// ¿Ya se alcanzó la meta?
    public fun meta_alcanzada(a: &Alcancia): bool {
        balance::value(&a.ahorro) >= a.meta
    }

    /// Progreso hacia la meta en porcentaje (0..=100). Se satura en 100.
    public fun progreso(a: &Alcancia): u64 {
        let total = balance::value(&a.ahorro);
        if (total >= a.meta) {
            100
        } else {
            // meta > 0 garantizado en `crear`.
            (((total as u128) * 100) / (a.meta as u128)) as u64
        }
    }

    /// Cuánto falta para alcanzar la meta (en MIST). 0 si ya se alcanzó.
    public fun faltante(a: &Alcancia): u64 {
        let total = balance::value(&a.ahorro);
        if (total >= a.meta) 0 else a.meta - total
    }
}

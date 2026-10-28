#[test_only]
module alcancia::alcancia_tests {
    use alcancia::alcancia::{Self, Alcancia};
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    const DUENO: address = @0xA11CE;
    const AMIGO: address = @0xB0B;

    const META: u64 = 1_000;

    // ----------------------------------------------------------------
    // Helpers
    // ----------------------------------------------------------------
    fun acunar(monto: u64, s: &mut Scenario): Coin<SUI> {
        coin::mint_for_testing<SUI>(monto, ts::ctx(s))
    }

    fun crear_alcancia(s: &mut Scenario) {
        ts::next_tx(s, DUENO);
        alcancia::crear(META, ts::ctx(s));
    }

    // ----------------------------------------------------------------
    // Camino feliz
    // ----------------------------------------------------------------
    #[test]
    fun crear_y_depositar() {
        let mut s = ts::begin(DUENO);
        crear_alcancia(&mut s);

        ts::next_tx(&mut s, AMIGO);
        {
            let mut a = ts::take_shared<Alcancia>(&s);
            assert!(alcancia::saldo(&a) == 0, 0);
            assert!(alcancia::meta(&a) == META, 1);
            assert!(alcancia::dueno(&a) == DUENO, 2);
            assert!(!alcancia::meta_alcanzada(&a), 3);
            assert!(alcancia::progreso(&a) == 0, 4);
            assert!(alcancia::faltante(&a) == META, 5);

            // un amigo deposita la mitad
            let c = acunar(META / 2, &mut s);
            alcancia::depositar(&mut a, c, ts::ctx(&mut s));

            assert!(alcancia::saldo(&a) == META / 2, 6);
            assert!(alcancia::progreso(&a) == 50, 7);
            assert!(alcancia::faltante(&a) == META / 2, 8);
            assert!(!alcancia::meta_alcanzada(&a), 9);
            ts::return_shared(a);
        };
        ts::end(s);
    }

    #[test]
    fun alcanzar_meta_y_retirar_todo() {
        let mut s = ts::begin(DUENO);
        crear_alcancia(&mut s);

        // depósito que alcanza exactamente la meta
        ts::next_tx(&mut s, DUENO);
        {
            let mut a = ts::take_shared<Alcancia>(&s);
            let c = acunar(META, &mut s);
            alcancia::depositar(&mut a, c, ts::ctx(&mut s));
            assert!(alcancia::meta_alcanzada(&a), 0);
            assert!(alcancia::progreso(&a) == 100, 1);
            assert!(alcancia::faltante(&a) == 0, 2);
            ts::return_shared(a);
        };

        // el dueño retira todo
        ts::next_tx(&mut s, DUENO);
        {
            let mut a = ts::take_shared<Alcancia>(&s);
            alcancia::retirar(&mut a, ts::ctx(&mut s));
            assert!(alcancia::saldo(&a) == 0, 3);
            ts::return_shared(a);
        };

        // el dueño recibió una moneda con la meta completa
        ts::next_tx(&mut s, DUENO);
        {
            let recibido = ts::take_from_sender<Coin<SUI>>(&s);
            assert!(coin::value(&recibido) == META, 4);
            ts::return_to_sender(&s, recibido);
        };
        ts::end(s);
    }

    #[test]
    fun retiro_parcial_deja_resto() {
        let mut s = ts::begin(DUENO);
        crear_alcancia(&mut s);

        ts::next_tx(&mut s, DUENO);
        {
            let mut a = ts::take_shared<Alcancia>(&s);
            let c = acunar(META * 2, &mut s);
            alcancia::depositar(&mut a, c, ts::ctx(&mut s));

            // saca solo la mitad de lo depositado
            alcancia::retirar_monto(&mut a, META, ts::ctx(&mut s));
            assert!(alcancia::saldo(&a) == META, 0);
            // la meta sigue alcanzada con el resto
            assert!(alcancia::meta_alcanzada(&a), 1);
            ts::return_shared(a);
        };
        ts::end(s);
    }

    #[test]
    fun progreso_se_satura_en_100() {
        let mut s = ts::begin(DUENO);
        crear_alcancia(&mut s);
        ts::next_tx(&mut s, DUENO);
        {
            let mut a = ts::take_shared<Alcancia>(&s);
            let c = acunar(META * 5, &mut s);
            alcancia::depositar(&mut a, c, ts::ctx(&mut s));
            assert!(alcancia::progreso(&a) == 100, 0);
            ts::return_shared(a);
        };
        ts::end(s);
    }

    // ----------------------------------------------------------------
    // Casos de fallo
    // ----------------------------------------------------------------
    #[test]
    #[expected_failure(abort_code = alcancia::EMetaCero)]
    fun crear_con_meta_cero_falla() {
        let mut s = ts::begin(DUENO);
        ts::next_tx(&mut s, DUENO);
        alcancia::crear(0, ts::ctx(&mut s));
        ts::end(s);
    }

    #[test]
    #[expected_failure(abort_code = alcancia::EDepositoCero)]
    fun depositar_cero_falla() {
        let mut s = ts::begin(DUENO);
        crear_alcancia(&mut s);
        ts::next_tx(&mut s, AMIGO);
        {
            let mut a = ts::take_shared<Alcancia>(&s);
            let c = acunar(0, &mut s);
            alcancia::depositar(&mut a, c, ts::ctx(&mut s));
            ts::return_shared(a);
        };
        ts::end(s);
    }

    #[test]
    #[expected_failure(abort_code = alcancia::ENoEresDueno)]
    fun retirar_sin_ser_dueno_falla() {
        let mut s = ts::begin(DUENO);
        crear_alcancia(&mut s);

        // se alcanza la meta
        ts::next_tx(&mut s, DUENO);
        {
            let mut a = ts::take_shared<Alcancia>(&s);
            let c = acunar(META, &mut s);
            alcancia::depositar(&mut a, c, ts::ctx(&mut s));
            ts::return_shared(a);
        };

        // un extraño intenta retirar
        ts::next_tx(&mut s, AMIGO);
        {
            let mut a = ts::take_shared<Alcancia>(&s);
            alcancia::retirar(&mut a, ts::ctx(&mut s));
            ts::return_shared(a);
        };
        ts::end(s);
    }

    #[test]
    #[expected_failure(abort_code = alcancia::EMetaNoAlcanzada)]
    fun retirar_sin_alcanzar_meta_falla() {
        let mut s = ts::begin(DUENO);
        crear_alcancia(&mut s);

        ts::next_tx(&mut s, DUENO);
        {
            let mut a = ts::take_shared<Alcancia>(&s);
            let c = acunar(META - 1, &mut s);
            alcancia::depositar(&mut a, c, ts::ctx(&mut s));
            alcancia::retirar(&mut a, ts::ctx(&mut s));
            ts::return_shared(a);
        };
        ts::end(s);
    }

    #[test]
    #[expected_failure(abort_code = alcancia::EFondosInsuficientes)]
    fun retirar_mas_de_lo_disponible_falla() {
        let mut s = ts::begin(DUENO);
        crear_alcancia(&mut s);

        ts::next_tx(&mut s, DUENO);
        {
            let mut a = ts::take_shared<Alcancia>(&s);
            let c = acunar(META, &mut s);
            alcancia::depositar(&mut a, c, ts::ctx(&mut s));
            // pide más de lo que hay
            alcancia::retirar_monto(&mut a, META + 1, ts::ctx(&mut s));
            ts::return_shared(a);
        };
        ts::end(s);
    }
}

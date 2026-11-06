-- Script SQL para gerar um ambiente de teste completo no Supabase / PostgreSQL.
-- Cobre todos os módulos: Veículos, Motoristas, Contratos, Financeiro/Ledger, Caixas,
-- Multas (traffic_fines, fine_appeals), Sinistros (claims), Manutenção (maintenance, work_orders, plans),
-- Modelos e Aditivos de Contrato (contract_templates, contract_aditivos, alert rules) e Usuários do sistema (RBAC).
--
-- Pode ser executado diretamente no SQL Editor do Supabase.

DO $$
DECLARE
    i INTEGER;
    tenant_id_val TEXT := 'tenant-1'; -- Empresa Táxi Amarelo S.A.
    
    -- IDs de teste
    v_id TEXT;
    v_plate TEXT;
    v_brand TEXT;
    v_model TEXT;
    v_year INTEGER;
    v_color TEXT;
    v_chassis TEXT;
    v_renavam TEXT;
    v_status TEXT;
    v_mileage INTEGER;
    v_next_maint INTEGER;
    v_notes TEXT;
    
    d_id TEXT;
    d_name TEXT;
    d_cpf TEXT;
    d_rg TEXT;
    d_phone TEXT;
    d_cnh TEXT;
    d_cnh_cat TEXT;
    d_status TEXT;
    
    c_id TEXT;
    c_rate NUMERIC;
    c_deposit NUMERIC;
    
    -- Listas para geração de nomes e carros
    first_names TEXT[] := ARRAY['João', 'Maria', 'Pedro', 'Ana', 'Carlos', 'Lucas', 'Julia', 'Marcos', 'Luiz', 'Amanda', 'Rodrigo', 'Bruno', 'Gabriel', 'Fernanda', 'Rafael', 'Diego', 'Patricia', 'Juliana', 'Thiago', 'Aline'];
    last_names TEXT[] := ARRAY['Silva', 'Santos', 'Oliveira', 'Souza', 'Rodrigues', 'Ferreira', 'Alves', 'Pereira', 'Lima', 'Gomes', 'Costa', 'Ribeiro', 'Martins', 'Carvalho', 'Almeida', 'Lopes', 'Soares', 'Dias', 'Vieira', 'Rocha'];
    
    brands TEXT[] := ARRAY['Chevrolet', 'Fiat', 'Volkswagen', 'Hyundai', 'Toyota', 'Renault', 'Ford', 'Nissan', 'Honda', 'Jeep'];
    colors TEXT[] := ARRAY['Branco', 'Preto', 'Prata', 'Cinza', 'Vermelho', 'Azul', 'Bronze', 'Verde'];
    
    brand_idx INTEGER;
    color_idx INTEGER;
    status_idx INTEGER;
    
    -- Caixa
    cashier_id_closed TEXT := 'cs-test-001';
    cashier_id_open TEXT := 'cs-test-002';
BEGIN
    -- =========================================================================
    -- 1. CONFIGURAÇÕES DA EMPRESA (TENANT)
    -- =========================================================================
    UPDATE saas_fleets 
    SET vehicle_limit = GREATEST(vehicle_limit, 200) 
    WHERE id = tenant_id_val;

    -- =========================================================================
    -- 2. GERAÇÃO DE PERFIS DE USUÁRIOS DE SISTEMA (RBAC / CONTROLE DE ACESSO)
    -- =========================================================================
    INSERT INTO user_profiles (id, email, display_name, role, role_id, tenant_id, active, supervisor_pin, created_at)
    VALUES 
        ('usr-test-manager', 'gerente@fleetsos.com', 'Marcos Gerente', 'manager', 'role-manager', tenant_id_val, TRUE, '2222', NOW() - INTERVAL '30 days'),
        ('usr-test-supervisor', 'supervisor@fleetsos.com', 'Patricia Supervisora', 'supervisor', 'role-supervisor', tenant_id_val, TRUE, '3333', NOW() - INTERVAL '30 days'),
        ('usr-test-financial', 'financeiro@fleetsos.com', 'Thiago Finanças', 'financial', 'role-financial', tenant_id_val, TRUE, '4444', NOW() - INTERVAL '30 days'),
        ('usr-test-cashier', 'caixa@fleetsos.com', 'Aline Caixa', 'cashier', 'role-cashier', tenant_id_val, TRUE, '5555', NOW() - INTERVAL '30 days'),
        ('usr-test-hr', 'rh@fleetsos.com', 'Fernanda RH', 'hr', 'role-hr', tenant_id_val, TRUE, '6666', NOW() - INTERVAL '30 days'),
        ('usr-test-readonly', 'consulta@fleetsos.com', 'Roberto Leitura', 'readonly', 'role-readonly', tenant_id_val, TRUE, '7777', NOW() - INTERVAL '30 days')
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        display_name = EXCLUDED.display_name,
        role = EXCLUDED.role,
        role_id = EXCLUDED.role_id,
        active = EXCLUDED.active;

    -- =========================================================================
    -- 3. GERAÇÃO DE 40 MOTORISTAS
    -- =========================================================================
    FOR i IN 1..40 LOOP
        d_id := 'drv-test-' || LPAD(i::text, 3, '0');
        
        d_name := first_names[1 + floor(random() * array_length(first_names, 1))] || ' ' || 
                  last_names[1 + floor(random() * array_length(last_names, 1))];
                  
        d_cpf := LPAD((i * 123)::text, 3, '0') || '.' || LPAD((i * 456)::text, 3, '0') || '.' || LPAD((i * 789)::text, 3, '0') || '-' || LPAD((i * 11)::text, 2, '0');
        d_rg := LPAD((i * 98765)::text, 9, '0');
        d_phone := '(11) 9' || LPAD((90000000 + i * 17)::text, 8, '0');
        d_cnh := LPAD((10000000000 + i * 99)::text, 11, '0');
        
        d_cnh_cat := CASE (i % 4)
            WHEN 0 THEN 'AB'
            WHEN 1 THEN 'B'
            WHEN 2 THEN 'D'
            ELSE 'AD'
        END;
        
        d_status := CASE 
            WHEN i <= 33 THEN 'active'
            WHEN i <= 37 THEN 'inactive'
            ELSE 'blocked'
        END;

        INSERT INTO drivers (
            id, tenant_id, name, cpf, rg, phone, condutax, condutax_expiration, alvara_number, alvara_expiration, cnh_number, cnh_category, cnh_expiration, address, status, notes, created_at
        ) VALUES (
            d_id, tenant_id_val, d_name, d_cpf, d_rg, d_phone, 'COND-' || (5000 + i), '2028-12-31', 'ALV-' || (1000 + i), '2027-06-30', d_cnh, d_cnh_cat, '2030-01-01', 'Rua de Teste, ' || (100 + i) || ' - São Paulo, SP', d_status, 'Motorista gerado em lote para testes.', NOW() - INTERVAL '30 days'
        ) ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            cpf = EXCLUDED.cpf,
            rg = EXCLUDED.rg,
            phone = EXCLUDED.phone,
            status = EXCLUDED.status;
            
        -- Cria também perfil de usuário para motoristas principais para simular login deles
        IF (i <= 5) THEN
            INSERT INTO user_profiles (id, email, display_name, role, role_id, tenant_id, active, created_at)
            VALUES ('usr-test-drv-' || i, 'motorista' || i || '@fleetsos.com', d_name, 'driver', 'role-driver', tenant_id_val, TRUE, NOW() - INTERVAL '30 days')
            ON CONFLICT (id) DO NOTHING;
        END IF;
    END LOOP;

    -- =========================================================================
    -- 4. GERAÇÃO DE 50 VEÍCULOS
    -- =========================================================================
    FOR i IN 1..50 LOOP
        v_id := 'veh-test-' || LPAD(i::text, 3, '0');
        v_plate := 'TST-' || LPAD(i::text, 4, '0');
        
        brand_idx := 1 + floor(random() * array_length(brands, 1));
        color_idx := 1 + floor(random() * array_length(colors, 1));
        v_brand := brands[brand_idx];
        v_color := colors[color_idx];
        
        v_status := CASE 
            WHEN i <= 30 THEN 'rented'
            WHEN i <= 45 THEN 'available'
            ELSE 'maintenance'
        END;
        
        v_model := CASE v_brand
            WHEN 'Chevrolet' THEN (ARRAY['Onix', 'Prisma', 'Spin', 'Tracker', 'Cruze'])[1 + floor(random() * 5)]
            WHEN 'Fiat' THEN (ARRAY['Uno', 'Argo', 'Cronos', 'Mobi', 'Strada'])[1 + floor(random() * 5)]
            WHEN 'Volkswagen' THEN (ARRAY['Gol', 'Polo', 'Voyage', 'Virtus', 'T-Cross'])[1 + floor(random() * 5)]
            WHEN 'Hyundai' THEN (ARRAY['HB20', 'HB20S', 'Creta', 'Tucson', 'Ix35'])[1 + floor(random() * 5)]
            WHEN 'Toyota' THEN (ARRAY['Corolla', 'Etios', 'Yaris', 'Hilux', 'Corolla Cross'])[1 + floor(random() * 5)]
            WHEN 'Renault' THEN (ARRAY['Kwid', 'Sandero', 'Logan', 'Duster', 'Captur'])[1 + floor(random() * 5)]
            WHEN 'Ford' THEN (ARRAY['Ka', 'Ka Sedan', 'EcoSport', 'Focus', 'Fiesta'])[1 + floor(random() * 5)]
            WHEN 'Nissan' THEN (ARRAY['Versa', 'Kicks', 'Sentra', 'March', 'Frontier'])[1 + floor(random() * 5)]
            WHEN 'Honda' THEN (ARRAY['Civic', 'Fit', 'City', 'HR-V', 'WR-V'])[1 + floor(random() * 5)]
            ELSE (ARRAY['Renegade', 'Compass', 'Commander', 'Cherokee', 'Patriot'])[1 + floor(random() * 5)]
        END;
        
        v_year := 2018 + (i % 9);
        v_chassis := '9BWZZZ99Z' || LPAD((i * 17)::text, 8, '0');
        v_renavam := '00' || LPAD((100000000 + i * 231)::text, 9, '0');
        v_mileage := 5000 + (i * 2400);
        v_next_maint := v_mileage + (10000 - (v_mileage % 10000));
        v_notes := 'Veículo gerado automaticamente para testes.';
        
        INSERT INTO vehicles (
            id, tenant_id, plate, brand, model, year, color, chassis, renavam, status, mileage, next_maintenance_mileage, notes, created_at
        ) VALUES (
            v_id, tenant_id_val, v_plate, v_brand, v_model, v_year, v_color, v_chassis, v_renavam, v_status, v_mileage, v_next_maint, v_notes, NOW() - INTERVAL '30 days'
        ) ON CONFLICT (id) DO UPDATE SET
            plate = EXCLUDED.plate,
            brand = EXCLUDED.brand,
            model = EXCLUDED.model,
            status = EXCLUDED.status,
            mileage = EXCLUDED.mileage;
    END LOOP;

    -- =========================================================================
    -- 5. CONTRATOS (30 ativos, 3 finalizados)
    -- =========================================================================
    
    -- 5.1 Contratos Ativos (con-test-001 a con-test-030)
    FOR i IN 1..30 LOOP
        c_id := 'con-test-' || LPAD(i::text, 3, '0');
        d_id := 'drv-test-' || LPAD(i::text, 3, '0');
        v_id := 'veh-test-' || LPAD(i::text, 3, '0');
        
        c_rate := 600.00 + (i % 5) * 50.00;
        c_deposit := 1500.00;
        
        INSERT INTO contracts (
            id, tenant_id, driver_id, vehicle_id, start_date, status, weekly_rate, deposit, created_at
        ) VALUES (
            c_id, tenant_id_val, d_id, v_id, TO_CHAR(NOW() - INTERVAL '21 days', 'YYYY-MM-DD'), 'active', c_rate, c_deposit, NOW() - INTERVAL '21 days'
        ) ON CONFLICT (id) DO UPDATE SET
            status = EXCLUDED.status,
            weekly_rate = EXCLUDED.weekly_rate,
            deposit = EXCLUDED.deposit;
            
        -- =====================================================================
        -- 6. MOVIMENTAÇÕES FINANCEIRAS (LEDGER) POR MOTORISTA ATIVO
        -- =====================================================================
        INSERT INTO driver_ledger (id, tenant_id, driver_id, type, description, amount, created_at)
        VALUES (
            'led-test-dep-' || LPAD(i::text, 3, '0'),
            tenant_id_val, d_id, 'payment', 'Depósito de caução do contrato ' || c_id, c_deposit, NOW() - INTERVAL '21 days'
        ) ON CONFLICT (id) DO NOTHING;

        INSERT INTO driver_ledger (id, tenant_id, driver_id, type, description, amount, created_at)
        VALUES 
            ('led-test-chg1-' || LPAD(i::text, 3, '0'), tenant_id_val, d_id, 'daily', 'Locação Semanal - Período 1', -c_rate, NOW() - INTERVAL '14 days'),
            ('led-test-chg2-' || LPAD(i::text, 3, '0'), tenant_id_val, d_id, 'daily', 'Locação Semanal - Período 2', -c_rate, NOW() - INTERVAL '7 days'),
            ('led-test-chg3-' || LPAD(i::text, 3, '0'), tenant_id_val, d_id, 'daily', 'Locação Semanal - Período 3', -c_rate, NOW())
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO driver_ledger (id, tenant_id, driver_id, type, description, amount, created_at)
        VALUES 
            ('led-test-pay1-' || LPAD(i::text, 3, '0'), tenant_id_val, d_id, 'payment', 'Pagamento de Locação Semanal (Pix)', c_rate, NOW() - INTERVAL '12 days'),
            ('led-test-pay2-' || LPAD(i::text, 3, '0'), tenant_id_val, d_id, 'payment', 'Pagamento de Locação Semanal (Cartão)', c_rate, NOW() - INTERVAL '5 days')
        ON CONFLICT (id) DO NOTHING;
        
        IF (i % 2 = 1) THEN
            INSERT INTO driver_ledger (id, tenant_id, driver_id, type, description, amount, created_at)
            VALUES (
                'led-test-maint-' || LPAD(i::text, 3, '0'),
                tenant_id_val, d_id, 'maintenance', 'Reembolso de manutenção autorizada', -80.00, NOW() - INTERVAL '3 days'
            ) ON CONFLICT (id) DO NOTHING;
        END IF;
    END LOOP;

    -- 5.2 Contratos Finalizados (con-test-031 a con-test-033)
    FOR i IN 31..33 LOOP
        c_id := 'con-test-' || LPAD(i::text, 3, '0');
        d_id := 'drv-test-' || LPAD(i::text, 3, '0');
        v_id := 'veh-test-' || LPAD(i::text, 3, '0');
        c_rate := 650.00;
        c_deposit := 1500.00;
        
        INSERT INTO contracts (
            id, tenant_id, driver_id, vehicle_id, start_date, end_date, status, weekly_rate, deposit, created_at
        ) VALUES (
            c_id, tenant_id_val, d_id, v_id, TO_CHAR(NOW() - INTERVAL '60 days', 'YYYY-MM-DD'), TO_CHAR(NOW() - INTERVAL '30 days', 'YYYY-MM-DD'), 'finished', c_rate, c_deposit, NOW() - INTERVAL '60 days'
        ) ON CONFLICT (id) DO UPDATE SET
            status = EXCLUDED.status,
            end_date = EXCLUDED.end_date;
            
        INSERT INTO driver_ledger (id, tenant_id, driver_id, type, description, amount, created_at)
        VALUES 
            ('led-test-dep-' || LPAD(i::text, 3, '0'), tenant_id_val, d_id, 'payment', 'Depósito de caução do contrato ' || c_id, c_deposit, NOW() - INTERVAL '60 days'),
            ('led-test-chg1-' || LPAD(i::text, 3, '0'), tenant_id_val, d_id, 'daily', 'Locação Semanal Finalizada', -c_rate, NOW() - INTERVAL '50 days'),
            ('led-test-pay1-' || LPAD(i::text, 3, '0'), tenant_id_val, d_id, 'payment', 'Pagamento Encerramento (Dinheiro)', c_rate, NOW() - INTERVAL '30 days'),
            ('led-test-refund-' || LPAD(i::text, 3, '0'), tenant_id_val, d_id, 'payment', 'Devolução de caução após vistoria', -c_deposit, NOW() - INTERVAL '30 days')
        ON CONFLICT (id) DO NOTHING;
    END LOOP;

    -- =========================================================================
    -- 7. CAIXA (CASHIER SESSIONS & MOVEMENTS)
    -- =========================================================================
    INSERT INTO cashier_sessions (
        id, tenant_id, opened_by, opened_by_name, opened_at, closed_at, opening_amount, closing_amount, expected_balance, difference, status, closed_by, closed_by_name, closure_type
    ) VALUES (
        cashier_id_closed, tenant_id_val, '00000000-0000-0000-0000-000000000002', 'Luiz Frota', NOW() - INTERVAL '8 days', NOW() - INTERVAL '7 days', 200.00, 1500.00, 1500.00, 0.00, 'closed', '00000000-0000-0000-0000-000000000002', 'Luiz Frota', 'standard'
    ) ON CONFLICT (id) DO UPDATE SET
        status = EXCLUDED.status,
        closing_amount = EXCLUDED.closing_amount;
        
    INSERT INTO cashier_movements (id, tenant_id, cashier_id, type, amount, payment_method, description, created_at)
    VALUES 
        ('cm-test-001', tenant_id_val, cashier_id_closed, 'RECEIPT', 650.00, 'Pix', 'Recebimento Locação - drv-test-001', NOW() - INTERVAL '7 days 23 hours'),
        ('cm-test-002', tenant_id_val, cashier_id_closed, 'RECEIPT', 700.00, 'Card', 'Recebimento Locação - drv-test-002', NOW() - INTERVAL '7 days 20 hours'),
        ('cm-test-003', tenant_id_val, cashier_id_closed, 'WITHDRAW', 50.00, 'Money', 'Sangria - Papelaria e café', NOW() - INTERVAL '7 days 18 hours')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO cashier_sessions (
        id, tenant_id, opened_by, opened_by_name, opened_at, closed_at, opening_amount, closing_amount, expected_balance, difference, status
    ) VALUES (
        cashier_id_open, tenant_id_val, '00000000-0000-0000-0000-000000000002', 'Luiz Frota', NOW() - INTERVAL '4 hours', NULL, 1500.00, 0.00, 1500.00, 0.00, 'open'
    ) ON CONFLICT (id) DO UPDATE SET
        status = EXCLUDED.status;

    INSERT INTO cashier_movements (id, tenant_id, cashier_id, type, amount, payment_method, description, created_at)
    VALUES 
        ('cm-test-004', tenant_id_val, cashier_id_open, 'RECEIPT', 750.00, 'Pix', 'Recebimento Semanal - drv-test-003', NOW() - INTERVAL '3 hours'),
        ('cm-test-005', tenant_id_val, cashier_id_open, 'RECEIPT', 800.00, 'Pix', 'Recebimento Semanal - drv-test-004', NOW() - INTERVAL '2 hours'),
        ('cm-test-006', tenant_id_val, cashier_id_open, 'WITHDRAW', 100.00, 'Money', 'Retirada para Troco Rápido', NOW() - INTERVAL '1 hour')
    ON CONFLICT (id) DO NOTHING;

    -- =========================================================================
    -- 8. SINCRONIZAÇÃO DE TOTAIS
    -- =========================================================================
    UPDATE saas_fleets
    SET vehicle_count = (SELECT COUNT(*) FROM vehicles WHERE tenant_id = tenant_id_val)
    WHERE id = tenant_id_val;
END $$;


-- =============================================================================
-- 9. POPULAR TABELAS DE COLEÇÃO (FLEETOS_COLLECTIONS) - MULTAS, SINISTROS, ETC.
-- =============================================================================

-- 9.1 MULTAS DE TRÂNSITO (traffic_fines)
INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('traffic_fines', 'fine-test-001', 'tenant-1', '{
    "id": "fine-test-001",
    "noticeNumber": "AIT98765401",
    "issuingAgency": "DETRAN-SP",
    "vehicleId": "veh-test-001",
    "plate": "TST-0001",
    "infractionCode": "7455-3",
    "description": "Transitar em velocidade superior à máxima permitida em até 20%",
    "fineCategory": "transit",
    "occurrenceDate": "2026-06-15T14:30:00.000Z",
    "receivedDate": "2026-06-20T10:00:00.000Z",
    "originalAmount": 130.16,
    "discountAmount": 26.03,
    "discountDeadline": "2026-07-20",
    "currentAmount": 130.16,
    "dueDate": "2026-08-05",
    "points": 4,
    "responsibleParty": "driver",
    "status": "driver_identified",
    "driverId": "drv-test-001",
    "driverName": "Carlos Santos",
    "identificationMethod": "manual",
    "timeline": [
      {"date": "2026-06-20T10:00:00.000Z", "label": "Multa Recebida", "detail": "AIT AIT98765401 — DETRAN-SP", "actor": "Sistema"},
      {"date": "2026-06-21T09:30:00.000Z", "label": "Condutor Identificado", "detail": "Carlos Santos", "actor": "Luiz Frota"}
    ]
}'::jsonb, NOW() - INTERVAL '10 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('traffic_fines', 'fine-test-002', 'tenant-1', '{
    "id": "fine-test-002",
    "noticeNumber": "AIT98765402",
    "issuingAgency": "SMT-SP",
    "vehicleId": "veh-test-002",
    "plate": "TST-0002",
    "infractionCode": "5681-0",
    "description": "Transitar em faixa exclusiva de ônibus de transporte público",
    "fineCategory": "transit",
    "occurrenceDate": "2026-06-16T08:15:00.000Z",
    "receivedDate": "2026-06-21T11:00:00.000Z",
    "originalAmount": 293.47,
    "discountAmount": 58.69,
    "discountDeadline": "2026-07-21",
    "currentAmount": 293.47,
    "dueDate": "2026-08-06",
    "points": 7,
    "responsibleParty": "driver",
    "status": "pending_driver_id",
    "identificationMethod": "pending",
    "timeline": [
      {"date": "2026-06-21T11:00:00.000Z", "label": "Multa Recebida", "detail": "AIT AIT98765402 — SMT-SP", "actor": "Sistema"}
    ]
}'::jsonb, NOW() - INTERVAL '9 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('traffic_fines', 'fine-test-003', 'tenant-1', '{
    "id": "fine-test-003",
    "noticeNumber": "AIT98765403",
    "issuingAgency": "DER-SP",
    "vehicleId": "veh-test-003",
    "plate": "TST-0003",
    "infractionCode": "6050-1",
    "description": "Avançar sinal vermelho do semáforo ou de parada obrigatória",
    "fineCategory": "transit",
    "occurrenceDate": "2026-06-18T23:45:00.000Z",
    "receivedDate": "2026-06-24T14:00:00.000Z",
    "originalAmount": 293.47,
    "discountAmount": 58.69,
    "discountDeadline": "2026-07-24",
    "currentAmount": 293.47,
    "dueDate": "2026-08-10",
    "points": 7,
    "responsibleParty": "driver",
    "status": "charged",
    "driverId": "drv-test-003",
    "driverName": "Marcos Silva",
    "identificationMethod": "auto",
    "arId": "led-test-chg3-003",
    "timeline": [
      {"date": "2026-06-24T14:00:00.000Z", "label": "Multa Recebida", "detail": "AIT AIT98765403 — DER-SP", "actor": "Sistema"},
      {"date": "2026-06-25T10:00:00.000Z", "label": "Condutor Identificado", "detail": "Marcos Silva (Identificação Automática)", "actor": "Sistema"},
      {"date": "2026-06-26T11:00:00.000Z", "label": "Cobrada no Ledger", "detail": "Multa lançada na conta corrente do motorista", "actor": "Sistema"}
    ]
}'::jsonb, NOW() - INTERVAL '6 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('traffic_fines', 'fine-test-004', 'tenant-1', '{
    "id": "fine-test-004",
    "noticeNumber": "AIT98765404",
    "issuingAgency": "DETRAN-SP",
    "vehicleId": "veh-test-004",
    "plate": "TST-0004",
    "infractionCode": "7463-0",
    "description": "Transitar em velocidade superior à máxima permitida em mais de 20% até 50%",
    "fineCategory": "transit",
    "occurrenceDate": "2026-06-19T10:20:00.000Z",
    "receivedDate": "2026-06-25T15:00:00.000Z",
    "originalAmount": 195.23,
    "discountAmount": 39.05,
    "discountDeadline": "2026-07-25",
    "currentAmount": 156.18,
    "dueDate": "2026-08-15",
    "points": 5,
    "responsibleParty": "driver",
    "status": "paid",
    "driverId": "drv-test-004",
    "driverName": "Juliana Costa",
    "identificationMethod": "manual",
    "timeline": [
      {"date": "2026-06-25T15:00:00.000Z", "label": "Multa Recebida", "detail": "AIT AIT98765404", "actor": "Sistema"},
      {"date": "2026-06-26T12:00:00.000Z", "label": "Condutor Identificado", "detail": "Juliana Costa", "actor": "Luiz Frota"},
      {"date": "2026-06-28T16:00:00.000Z", "label": "Quitada", "detail": "Pago com 20% de desconto pelo motorista", "actor": "Aline Caixa"}
    ]
}'::jsonb, NOW() - INTERVAL '5 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('traffic_fines', 'fine-test-005', 'tenant-1', '{
    "id": "fine-test-005",
    "noticeNumber": "AIT98765405",
    "issuingAgency": "SMT-SP",
    "vehicleId": "veh-test-005",
    "plate": "TST-0005",
    "infractionCode": "5550-0",
    "description": "Estacionar o veículo em local/horário proibido especificamente pela sinalização",
    "fineCategory": "transit",
    "occurrenceDate": "2026-06-20T11:45:00.000Z",
    "receivedDate": "2026-06-26T16:30:00.000Z",
    "originalAmount": 130.16,
    "discountAmount": 26.03,
    "discountDeadline": "2026-07-26",
    "currentAmount": 130.16,
    "dueDate": "2026-08-20",
    "points": 4,
    "responsibleParty": "driver",
    "status": "appealing",
    "driverId": "drv-test-005",
    "driverName": "Thiago Souza",
    "identificationMethod": "manual",
    "appealId": "appeal-test-001",
    "timeline": [
      {"date": "2026-06-26T16:30:00.000Z", "label": "Multa Recebida", "detail": "AIT AIT98765405", "actor": "Sistema"},
      {"date": "2026-06-27T10:00:00.000Z", "label": "Condutor Identificado", "detail": "Thiago Souza", "actor": "Luiz Frota"},
      {"date": "2026-06-29T14:00:00.000Z", "label": "Recurso Interposto", "detail": "Recurso em 1ª Instância protocolado", "actor": "Thiago Souza"}
    ]
}'::jsonb, NOW() - INTERVAL '4 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;


-- 9.2 RECURSOS DE MULTAS (fine_appeals)
INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('fine_appeals', 'appeal-test-001', 'tenant-1', '{
    "id": "appeal-test-001",
    "fineId": "fine-test-005",
    "type": "1st_instance",
    "grounds": "A placa de regulamentação de proibição de estacionamento encontrava-se totalmente encoberta por árvores na via pública impedindo sua visualização.",
    "submittedAt": "2026-06-29T14:00:00.000Z",
    "deadline": "2026-07-26",
    "status": "pending",
    "createdAt": "2026-06-29T14:00:00.000Z"
}'::jsonb, NOW() - INTERVAL '1 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;


-- 9.3 SINISTROS / ACIDENTES (claims)
INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('claims', 'claim-test-001', 'tenant-1', '{
    "id": "claim-test-001",
    "tenantId": "tenant-1",
    "claimNumber": "SIN-2026-0001",
    "vehicleId": "veh-test-001",
    "driverId": "drv-test-001",
    "contractId": "con-test-001",
    "occurrenceDate": "2026-06-20T18:30:00.000Z",
    "status": "Oficina",
    "severity": "medium",
    "location": "Av. Rebouças, 1200 - São Paulo, SP",
    "description": "Colisão traseira envolvendo terceiro. O motorista freou bruscamente devido a pedestre e o terceiro colidiu na traseira do Corolla Cross.",
    "involvedThirdParties": true,
    "hasVictims": false,
    "vehicleDrivable": true,
    "createdBy": "usr-test-manager",
    "createdAt": "2026-06-20T19:00:00.000Z",
    "culprit": "third_party",
    "accidentType": "Colisão Traseira",
    "startsEngine": true,
    "vehicleMoves": true,
    "steeringOk": true,
    "brakesOk": true,
    "coolingSystemOk": true,
    "electricalSystemOk": true,
    "airbagsDeployed": false,
    "fluidLeak": false,
    "suspensionDamage": false,
    "wheelDamage": false,
    "windshieldDamage": false,
    "headlightDamage": true
}'::jsonb, NOW() - INTERVAL '10 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('claims', 'claim-test-002', 'tenant-1', '{
    "id": "claim-test-002",
    "tenantId": "tenant-1",
    "claimNumber": "SIN-2026-0002",
    "vehicleId": "veh-test-002",
    "driverId": "drv-test-002",
    "contractId": "con-test-002",
    "occurrenceDate": "2026-06-25T11:15:00.000Z",
    "status": "Aguardando BO",
    "severity": "light",
    "location": "Marginal Pinheiros, km 12 - São Paulo, SP",
    "description": "Pequeno esbarrão ao trocar de faixa na pista expressa. Danificou retrovisor esquerdo.",
    "involvedThirdParties": true,
    "hasVictims": false,
    "vehicleDrivable": true,
    "createdBy": "usr-test-manager",
    "createdAt": "2026-06-25T12:00:00.000Z",
    "culprit": "driver",
    "accidentType": "Abalroamento Lateral",
    "startsEngine": true,
    "vehicleMoves": true,
    "steeringOk": true,
    "brakesOk": true,
    "coolingSystemOk": true,
    "electricalSystemOk": true,
    "airbagsDeployed": false,
    "fluidLeak": false,
    "suspensionDamage": false,
    "wheelDamage": false,
    "windshieldDamage": false,
    "headlightDamage": false
}'::jsonb, NOW() - INTERVAL '5 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('claims', 'claim-test-003', 'tenant-1', '{
    "id": "claim-test-003",
    "tenantId": "tenant-1",
    "claimNumber": "SIN-2026-0003",
    "vehicleId": "veh-test-003",
    "driverId": "drv-test-003",
    "contractId": "con-test-003",
    "occurrenceDate": "2026-06-28T02:00:00.000Z",
    "status": "Sob Análise",
    "severity": "severe",
    "location": "Cruzamento Av. Ipiranga com Av. São João - São Paulo, SP",
    "description": "Cruzou semáforo e foi atingido na lateral. Carro precisou ser guinchado devido a vazamento de óleo e radiador quebrado.",
    "involvedThirdParties": true,
    "hasVictims": false,
    "vehicleDrivable": false,
    "createdBy": "usr-test-manager",
    "createdAt": "2026-06-28T03:00:00.000Z",
    "culprit": "driver",
    "accidentType": "Colisão Transversal",
    "startsEngine": false,
    "vehicleMoves": false,
    "steeringOk": false,
    "brakesOk": true,
    "coolingSystemOk": false,
    "electricalSystemOk": false,
    "airbagsDeployed": true,
    "fluidLeak": true,
    "suspensionDamage": true,
    "wheelDamage": true,
    "windshieldDamage": true,
    "headlightDamage": true,
    "needsTowTruck": true,
    "towTruckRequested": true
}'::jsonb, NOW() - INTERVAL '2 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;


-- 9.4 REGISTROS DE MANUTENÇÃO (maintenance - MaintenanceLog)
INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('maintenance', 'maint-test-001', 'tenant-1', '{
    "id": "maint-test-001",
    "vehicleId": "veh-test-001",
    "type": "Preventiva",
    "description": "Revisão periódica de 15.000km: Troca de óleo, filtro de combustível, filtro de cabine e rodízio de pneus.",
    "cost": 650.00,
    "date": "2026-06-10T09:00:00.000Z",
    "mileage": 15000,
    "nextMaintenanceMileage": 25000
}'::jsonb, NOW() - INTERVAL '20 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('maintenance', 'maint-test-002', 'tenant-1', '{
    "id": "maint-test-002",
    "vehicleId": "veh-test-002",
    "type": "Corretiva",
    "description": "Substituição emergencial das pastilhas de freio dianteiras e retífica dos discos que estavam apresentando ruídos.",
    "cost": 420.00,
    "date": "2026-06-15T14:00:00.000Z",
    "mileage": 42100,
    "nextMaintenanceMileage": 52100
}'::jsonb, NOW() - INTERVAL '15 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('maintenance', 'maint-test-003', 'tenant-1', '{
    "id": "maint-test-003",
    "vehicleId": "veh-test-003",
    "type": "Sinistro",
    "description": "Reparos estéticos de funilaria na lateral esquerda decorrentes de pequena colisão. Troca da moldura da porta.",
    "cost": 1500.00,
    "date": "2026-06-22T08:30:00.000Z",
    "mileage": 12200,
    "nextMaintenanceMileage": 22200,
    "crashSeverity": "Leve"
}'::jsonb, NOW() - INTERVAL '8 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;


-- 9.5 PLANOS DE MANUTENÇÃO (maintenance_plans)
INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('maintenance_plans', 'mp-test-001', 'tenant-1', '{
    "id": "mp-test-001",
    "name": "Plano de Manutenção Flex 10k",
    "manufacturer": "Chevrolet / Volkswagen",
    "category": "flex",
    "applicableModels": ["Onix", "Gol", "Voyage", "Polo"],
    "procedures": ["proc-oil-change", "proc-brakes-check", "proc-alignment"],
    "isDefault": true,
    "notes": "Plano padrão recomendado para veículos compactos flex a cada 10.000 km."
}'::jsonb, NOW() - INTERVAL '30 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('maintenance_plans', 'mp-test-002', 'tenant-1', '{
    "id": "mp-test-002",
    "name": "Plano de Manutenção GNV Especial",
    "manufacturer": "Chevrolet",
    "category": "gnv",
    "applicableModels": ["Spin"],
    "procedures": ["proc-oil-change", "proc-gnv-inspection", "proc-spark-plugs"],
    "isDefault": false,
    "notes": "Controle adicional para veículos rodando no GNV devido ao desgaste prematuro de velas e necessidade de homologação anual do cilindro."
}'::jsonb, NOW() - INTERVAL '30 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;


-- 9.6 PROCEDIMENTOS DE MANUTENÇÃO (maintenance_procedures)
INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('maintenance_procedures', 'proc-oil-change', 'tenant-1', '{
    "id": "proc-oil-change",
    "name": "Troca de Óleo do Motor e Filtro",
    "category": "oil",
    "intervalKm": 10000,
    "intervalDays": 180,
    "estimatedDurationMinutes": 45,
    "mandatory": true,
    "notes": "Usar apenas óleo sintético recomendado pelo manual de fábrica (5W30)."
}'::jsonb, NOW() - INTERVAL '30 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('maintenance_procedures', 'proc-brakes-check', 'tenant-1', '{
    "id": "proc-brakes-check",
    "name": "Revisão e Troca de Pastilhas de Freio",
    "category": "brake",
    "intervalKm": 20000,
    "intervalDays": null,
    "estimatedDurationMinutes": 60,
    "mandatory": true,
    "notes": "Verificar espessura do disco de freio e nível do fluído DOT 4."
}'::jsonb, NOW() - INTERVAL '30 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('maintenance_procedures', 'proc-gnv-inspection', 'tenant-1', '{
    "id": "proc-gnv-inspection",
    "name": "Revisão Completa de GNV e Filtro",
    "category": "gnv",
    "intervalKm": 10000,
    "intervalDays": 365,
    "estimatedDurationMinutes": 90,
    "mandatory": true,
    "notes": "Verificar mangueiras de gás, regulador de pressão e substituir filtro de GNV de 5ª geração."
}'::jsonb, NOW() - INTERVAL '30 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;


-- 9.7 ORDENS DE SERVIÇO DE MANUTENÇÃO (work_orders)
INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('work_orders', 'wo-test-001', 'tenant-1', '{
    "id": "wo-test-001",
    "vehicleId": "veh-test-001",
    "description": "Corrigir ruído ao frear e fazer alinhamento total de direção.",
    "status": "completed",
    "mileage": 15150,
    "totalPartsCost": 120.00,
    "totalLaborCost": 180.00,
    "totalCost": 300.00,
    "operatorId": "usr-test-manager",
    "createdAt": "2026-06-25T08:00:00.000Z",
    "completedAt": "2026-06-25T12:00:00.000Z"
}'::jsonb, NOW() - INTERVAL '5 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('work_orders', 'wo-test-002', 'tenant-1', '{
    "id": "wo-test-002",
    "vehicleId": "veh-test-002",
    "description": "Veículo falhando ao ligar pela manhã. Provável problema em velas de ignição ou bobina.",
    "status": "in_progress",
    "mileage": 42500,
    "totalPartsCost": 0.00,
    "totalLaborCost": 0.00,
    "totalCost": 0.00,
    "operatorId": "usr-test-manager",
    "createdAt": "2026-06-29T10:00:00.000Z"
}'::jsonb, NOW() - INTERVAL '1 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;


-- 9.8 ITENS DE ORDEM DE SERVIÇO (work_order_items)
INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('work_order_items', 'woi-test-001', 'tenant-1', '{
    "id": "woi-test-001",
    "workOrderId": "wo-test-001",
    "type": "PART",
    "itemId": null,
    "description": "Pastilhas de freio dianteiras Fras-le",
    "qty": 1,
    "unitCost": 120.00,
    "totalCost": 120.00
}'::jsonb, NOW() - INTERVAL '5 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('work_order_items', 'woi-test-002', 'tenant-1', '{
    "id": "woi-test-002",
    "workOrderId": "wo-test-001",
    "type": "LABOR",
    "itemId": null,
    "description": "Mão de obra - Substituição de pastilhas e regulagem",
    "qty": 1,
    "unitCost": 100.00,
    "totalCost": 100.00
}'::jsonb, NOW() - INTERVAL '5 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('work_order_items', 'woi-test-003', 'tenant-1', '{
    "id": "woi-test-003",
    "workOrderId": "wo-test-001",
    "type": "LABOR",
    "itemId": null,
    "description": "Serviço de Alinhamento e Balanceamento das 4 rodas",
    "qty": 1,
    "unitCost": 80.00,
    "totalCost": 80.00
}'::jsonb, NOW() - INTERVAL '5 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;


-- 9.9 CATÁLOGO TÉCNICO DE ESPECIFICAÇÃO DE VEÍCULOS (vehicle_catalog)
INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('vehicle_catalog', 'cat-test-001', 'tenant-1', '{
    "id": "cat-test-001",
    "make": "Chevrolet",
    "model": "Onix Hatch / Plus",
    "engine": "1.0 12V 3Cil Turbo Ecotec",
    "yearFrom": 2020,
    "yearTo": 2026,
    "category": "flex",
    "defaultPlanId": "mp-test-001",
    "specs": [
        {"type": "oil", "description": "Óleo sintético Dexos 1 Gen 3 (0W20)", "partNumber": "GM-98553886", "quantity": 3.7, "unit": "litros", "notes": "Trocar sempre junto com o filtro de óleo."},
        {"type": "filter_oil", "description": "Filtro de óleo original", "partNumber": "ACDelco-12696048", "quantity": 1, "unit": "unidade", "notes": ""},
        {"type": "spark_plug", "description": "Jogo de Velas de Ignição Iridium", "partNumber": "NGK-ILKAR7B7G", "quantity": 3, "unit": "unidades", "notes": "Torque recomendado: 18 Nm."}
    ],
    "notes": "Especificação técnica padrão para a segunda geração do Chevrolet Onix de 2020 a 2026."
}'::jsonb, NOW() - INTERVAL '30 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;


-- 9.10 MODELOS DE CONTRATOS (contract_templates)
INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('contract_templates', 'tpl-test-001', 'tenant-1', '{
    "id": "tpl-test-001",
    "name": "Contrato de Locação Semanal de Táxi Padrão",
    "category": "Locação",
    "body": "CONTRATO DE LOCAÇÃO DE VEÍCULO AUTOMOTOR PARA FINS OPERACIONAIS DE TÁXI\n\nLOCADOR: Táxi Amarelo S.A.\nLOCATÁRIO: {{driver_name}}, inscrito no CPF sob o nº {{driver_cpf}}, portador da CNH nº {{driver_cnh}}.\n\nVEÍCULO: Marca {{vehicle_brand}}, Modelo {{vehicle_model}}, cor cinza, Placa {{vehicle_plate}}.\n\nCLÁUSULA 1ª: O valor da taxa de locação semanal cobrada será de R$ {{daily_rate}}, devendo ser paga toda semana via Pix ou Cartão.\nCLÁUSULA 2ª: Fica estipulado o depósito de garantia (caução) no valor de R$ 1.500,00 que será devolvido após encerramento do contrato.",
    "createdAt": "2026-06-01T10:00:00.000Z"
}'::jsonb, NOW() - INTERVAL '29 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('contract_templates', 'tpl-test-002', 'tenant-1', '{
    "id": "tpl-test-002",
    "name": "Termo de Entrega e Responsabilidade Civil",
    "category": "Entrega",
    "body": "TERMO DE ENTREGA, VISTORIA E RESPONSABILIDADE CIVIL DO VEÍCULO\n\nNesta data, o motorista {{driver_name}} declara que recebe o veículo placa {{vehicle_plate}} em perfeitas condições de uso, higiene e conservação.\n\nFica de responsabilidade civil e técnica do motorista a condução segura, bem como o pagamento de eventuais multas de trânsito ocorridas no período de posse e a franquia em caso de acidentes de trânsito.",
    "createdAt": "2026-06-01T10:00:00.000Z"
}'::jsonb, NOW() - INTERVAL '29 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;


-- 9.11 TERMOS ADITIVOS DE CONTRATO (contract_aditivos)
INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('contract_aditivos', 'adit-test-001', 'tenant-1', '{
    "id": "adit-test-001",
    "contractId": "con-test-001",
    "type": "Vigência",
    "notes": "Prorrogação de prazo de vigência por mais 6 meses, mantendo demais cláusulas.",
    "body": "TERMO ADITIVO DE VIGÊNCIA DE CONTRATO - REF: con-test-001\n\nFica prorrogado o contrato de locação con-test-001 por mais 6 meses a contar de hoje. As partes mantêm inalteradas todas as demais disposições de taxas e multas contratuais.",
    "createdAt": "2026-06-25T10:00:00.000Z"
}'::jsonb, NOW() - INTERVAL '5 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('contract_aditivos', 'adit-test-002', 'tenant-1', '{
    "id": "adit-test-002",
    "contractId": "con-test-002",
    "type": "Valor",
    "notes": "Ajuste na taxa semanal devido a reequilíbrio financeiro.",
    "body": "TERMO ADITIVO DE VALOR E TAXA DE LOCAÇÃO - REF: con-test-002\n\nAs partes concordam que, a partir do próximo ciclo de faturamento, o valor semanal passará a ser R$ 750,00 semanais devido ao reajuste anual de mercado e seguro.",
    "createdAt": "2026-06-28T14:30:00.000Z"
}'::jsonb, NOW() - INTERVAL '2 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;


-- 9.12 REGRAS DE ALERTA DO SAAS (saas_alert_rules)
INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('saas_alert_rules', 'rule-test-001', 'tenant-1', '{
    "id": "rule-test-001",
    "name": "Alerta de Vencimento de CNH de Motorista",
    "daysBefore": 30,
    "channel": "sms_whatsapp",
    "roleToNotify": "role-hr",
    "active": true
}'::jsonb, NOW() - INTERVAL '30 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

INSERT INTO fleetos_collections (collection_name, doc_id, tenant_id, data, created_at)
VALUES 
('saas_alert_rules', 'rule-test-002', 'tenant-1', '{
    "id": "rule-test-002",
    "name": "Alerta de Revisão Preventiva por Km",
    "daysBefore": 7,
    "channel": "system_push",
    "roleToNotify": "role-manager",
    "active": true
}'::jsonb, NOW() - INTERVAL '30 days')
ON CONFLICT (collection_name, doc_id) DO UPDATE SET data = EXCLUDED.data;

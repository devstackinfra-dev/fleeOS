-- Script SQL para gerar uma frota de teste com 50 veículos no Supabase / PostgreSQL.
-- Pode ser executado diretamente no SQL Editor do Supabase.

DO $$
DECLARE
    i INTEGER;
    tenant_id_val TEXT := 'tenant-1'; -- Altere para 'tenant-2' ou outro ID de empresa se necessário.
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
    
    -- Arrays para geração aleatória
    brands TEXT[] := ARRAY['Chevrolet', 'Fiat', 'Volkswagen', 'Hyundai', 'Toyota', 'Renault', 'Ford', 'Nissan', 'Honda', 'Jeep'];
    colors TEXT[] := ARRAY['Branco', 'Preto', 'Prata', 'Cinza', 'Vermelho', 'Azul', 'Bronze', 'Verde'];
    statuses TEXT[] := ARRAY['available', 'available', 'available', 'rented', 'rented', 'maintenance']; -- Distribuído de forma realista
    
    brand_idx INTEGER;
    color_idx INTEGER;
    status_idx INTEGER;
BEGIN
    -- 1. Garante que o limite de veículos do plano da empresa é suficiente (ex: 100)
    UPDATE saas_fleets 
    SET vehicle_limit = GREATEST(vehicle_limit, 100) 
    WHERE id = tenant_id_val;

    -- 2. Loop para inserir 50 veículos
    FOR i IN 1..50 LOOP
        v_id := 'veh-test-' || LPAD(i::text, 3, '0');
        v_plate := 'TST-' || LPAD(i::text, 4, '0');
        
        -- Seleciona marca e cor aleatória
        brand_idx := 1 + floor(random() * array_length(brands, 1));
        color_idx := 1 + floor(random() * array_length(colors, 1));
        status_idx := 1 + floor(random() * array_length(statuses, 1));
        
        v_brand := brands[brand_idx];
        v_color := colors[color_idx];
        v_status := statuses[status_idx];
        
        -- Seleciona modelo condizente com a marca
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
        
        -- Ano entre 2018 e 2026
        v_year := 2018 + floor(random() * 9);
        
        -- Dados de chassi e renavam fakes
        v_chassis := '9BWZZZ99Z' || LPAD((i * 17)::text, 8, '0');
        v_renavam := '00' || LPAD((100000000 + i * 231)::text, 9, '0');
        
        -- Quilometragem realista (entre 1.000km e 150.000km)
        v_mileage := 1000 + floor(random() * 149000);
        v_next_maint := v_mileage + (10000 - (v_mileage % 10000));
        
        v_notes := 'Veículo gerado automaticamente para testes. Lote #' || i;
        
        -- Insere ou atualiza o veículo
        INSERT INTO vehicles (
            id, tenant_id, plate, brand, model, year, color, chassis, renavam, status, mileage, next_maintenance_mileage, notes, created_at
        ) VALUES (
            v_id, tenant_id_val, v_plate, v_brand, v_model, v_year, v_color, v_chassis, v_renavam, v_status, v_mileage, v_next_maint, v_notes, NOW()
        ) ON CONFLICT (id) DO UPDATE SET
            plate = EXCLUDED.plate,
            brand = EXCLUDED.brand,
            model = EXCLUDED.model,
            year = EXCLUDED.year,
            color = EXCLUDED.color,
            chassis = EXCLUDED.chassis,
            renavam = EXCLUDED.renavam,
            status = EXCLUDED.status,
            mileage = EXCLUDED.mileage,
            next_maintenance_mileage = EXCLUDED.next_maintenance_mileage,
            notes = EXCLUDED.notes;
    END LOOP;

    -- 3. Atualiza o contador de veículos da empresa no painel de planos (saas_fleets)
    UPDATE saas_fleets
    SET vehicle_count = (SELECT COUNT(*) FROM vehicles WHERE tenant_id = tenant_id_val)
    WHERE id = tenant_id_val;
    
    RAISE NOTICE '50 veículos de teste criados/atualizados com sucesso para o tenant %!', tenant_id_val;
END $$;
